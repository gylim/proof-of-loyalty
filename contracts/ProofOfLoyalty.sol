// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "https://github.com/UMAprotocol/protocol/blob/master/packages/core/contracts/oracle/interfaces/OptimisticOracleV2Interface.sol";

import {ISuperfluid, ISuperToken, ISuperApp} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {ISuperfluidToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluidToken.sol";
import {ISuperTokenFactory} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperTokenFactory.sol";
import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import {CFAv1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";
import {IInstantDistributionAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import {IDAv1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/IDAv1Library.sol";

error Unauthorized();

contract ProofOfLoyalty {

    using SafeCast for int96;

    address public owner;
    uint public startDate;
    uint public endDate;
    uint public duration;
    uint public perParticipant;
    uint public maxParticipants;
    uint public numParticipants = 0;
    int96 private flowRate;

    struct details {
        uint registerTime;
        uint endDate;
        string twitterHandle;
    }
    mapping(address => details) public participantDetails;

    /// @notice CFA Library.
    using CFAv1Library for CFAv1Library.InitData;
    CFAv1Library.InitData public cfaV1;

    /// @notice IDA Library.
    using IDAv1Library for IDAv1Library.InitData;
    IDAv1Library.InitData public idaV1;

    uint32 public constant INDEX_ID = 0; // IDA index used for the ending distribution
    ISuperToken public rewardToken;

    /// @notice Super Token Factory
    ISuperTokenFactory public stf;

    // Create an Optimistic oracle instance at the deployed address on Kovan.
    OptimisticOracleV2Interface oo = OptimisticOracleV2Interface(0xA5B9d8a0B0Fa04Ba71BDD68069661ED5C0848884);

    // Use the yes no idetifier to ask arbitary questions, such as the weather on a particular day.
    bytes32 identifier = bytes32("YES_OR_NO_QUERY");

    constructor(ISuperfluid _host, address _owner) {
        assert(address(_host) != address(0));
        owner = _owner;

        // Initialise CFA Library
        cfaV1 = CFAv1Library.InitData(host, IConstantFlowAgreementV1(
                address(_host.getAgreementClass(keccak256(
                    "org.superfluid-finance.agreements.ConstantFlowAgreement.v1")))
            )
        );

        // Initialise Super Token Factory interface
        stf = ISuperTokenFactory(address(_host.getSuperTokenFactory()));

        // Initialise IDA library
        idaV1 = IDAv1Library.InitData(_host, IInstantDistributionAgreementV1(
                address(_host.getAgreementClass(keccak256(
                    "org.superfluid-finance.agreements.InstantDistributionAgreement.v1")))
            )
        );
    }

    /* * * * * * * * * * * * * * * * */
    /* CAMPAIGN SUPERFLUID FUNCTIONS */
    /* * * * * * * * * * * * * * * * */

    /// @notice Create SuperToken from ERC20 if none exists on current network, frontend will check list of existing SuperTokens
    function makeERC20SuperToken(IERC20 underlyingToken, uint8 underlyingDecimals,
        Upgradability upgradability, string calldata name, string calldata symbol)
        returns (ISuperToken superToken) {
            return stf.createERC20Wrapper(underlyingToken, underlyingDecimals, upgradability, name, symbol);
    }

    /// @notice Send a lump sum of super tokens into the contract. @dev This requires a super token ERC20 approval.
    /// @param _token Super Token to transfer. @param _amount Amount to transfer. @param _maxAmt reward per participant
    /// @param _startDate commencement of campaign, @param _endDate last day for registering, @param _duration length of campaign
    function commenceCampaign(ISuperToken _token, uint _amount, uint _maxAmt, uint _startDate, uint _endDate, uint _duration) external {
        require (_startDate < _endDate);
        if (msg.sender != owner) revert Unauthorized();
        // Deposit reward
        _token.transferFrom(msg.sender, address(this), _amount);
        // Initialise parameters of campaign, calculate flow rate
        perParticipant = _maxAmt;
        maxParticipants = _amount / _maxAmt;
        startDate = _startDate;
        endDate = _endDate;
        duration = _duration;
        flowRate = toInt96(int(perParticipant / duration));
        // IDA activated for token after lumpsum transferred in
        rewardToken = _token;
        idaV1.createIndex(rewardToken, INDEX_ID);
    }

    /// @notice Self-help registration for airdrop/marketing campaign
    function subscribeAirdrop(string calldata _twitterHandle) external {
        // check that campaign started, hasn't ended & there is still space for new registrants
        require(block.timestamp > startDate);
        require(block.timestamp < endDate);
        require(numParticipants < maxParticipants);
        cfaV1.createFlow(msg.sender, rewardToken, flowRate);
        // Get current units subscriber holds
        (, , uint256 currentUnitsHeld, ) = idaV1.getSubscription(rewardToken, address(this), INDEX_ID, msg.sender);
        // Update to current amount + 1
        idaV1.updateSubscriptionUnits(rewardToken, INDEX_ID, msg.sender, uint128(currentUnitsHeld + 1));
        // increment participants and record details
        numParticipants += 1;
        participantDetails[msg.sender].registerTime = block.timestamp;
        participantDetails[msg.sender].endDate = block.timestamp + duration;
        participantDetails[msg.sender].twitterHandle = _twitterHandle;
        // trigger UMA oracle to check if the user is real
        requestPrice(participantDetails[msg.sender].registerTime, participantDetails[msg.sender].twitterHandle);
    }

    /// @notice Delete flow from contract to specified address.
    /// @param token Token to stop streaming. @param receiver Receiver of stream.
    function deleteSubscriber(ISuperfluidToken token, address receiver) public {
        // if (msg.sender != owner) revert Unauthorized();
        cfaV1.deleteFlow(address(this), receiver, rewardToken); // does the third argument have to be a ISuperfluidToken?
        // remove shares of any leftover tokens
        idaV1.deleteSubscription(rewardToken, address(this), INDEX_ID, receiver);
    }

    /// @notice MIGHT NOT NEED lets an account lose a single distribution unit
    /// @param receiver subscriber address whose units are to be decremented
    function loseShare(address receiver) public {
        // Get current units subscriber holds
        (, , uint256 currentUnitsHeld, ) = idaV1.getSubscription(rewardToken, address(this), INDEX_ID, receiver);
        // Update to current amount - 1 (reverts if currentUnitsHeld - 1 < 0, so basically if currentUnitsHeld = 0)
        idaV1.updateSubscriptionUnits(rewardToken, INDEX_ID, receiver, uint128(currentUnitsHeld - 1));
    }

    /// @notice Takes the remaining balance of rewardToken in contract and distributes it to unit holders w/ IDA
    function distribute() external {
        // check campaign has ended and caller is owner
        require(block.timestamp > endDate);
        if (msg.sender != owner) revert Unauthorized();
        // distribute tokens
        uint256 rewardTokenBalance = rewardToken.balanceOf(address(this));
        (uint256 actualDistributionAmount, ) = idaV1.ida.calculateDistribution(
            rewardToken, address(this), INDEX_ID, rewardTokenBalance
        );
        idaV1.distribute(rewardToken, INDEX_ID, actualDistributionAmount);
    }

    /*  * * * * * * * * * * */
    /* UMA ORACLE FUNCTIONS */
    /* * * * * * * * * *  * */

    // Submit a data request to the Optimistic oracle.
    function requestPrice(uint requestTime, string calldata _userAccount) public {
        IERC20 bondCurrency = IERC20(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6); // Use Görli WETH as the bond currency.
        uint256 reward = 0; // Set the reward to 0 (so we dont have to fund it from this contract).

        bytes ancillaryData = bytes(string.concat("Q:Is user", _userAccount , "a legitimate account? A:1 for yes. 0 for no."));

        // make request to Optimistic oracle and set liveness to 1 day
        oo.requestPrice(identifier, requestTime, ancillaryData, bondCurrency, reward);
        oo.setCustomLiveness(identifier, requestTime, ancillaryData, 86400);
    }

    // Settle the request once it's gone through the liveness period. This acts to finalize the voted on outcome.
    function settleRequests(uint requestTime, string calldata  _userAccount) public {
        bytes ancillaryData = bytes(string.concat("Q:Is user", _userAccount , "a legitimate account? A:1 for yes. 0 for no."));
        oo.settle(address(this), identifier, requestTime, ancillaryData);
    }

    // Fetch the resolved price from the Optimistic oracle that was settled.
    function getSettledPrice(uint requestTime, string calldata _userAccount) public view returns (int256) {
        bytes ancillaryData = bytes(string.concat("Q:Is user", _userAccount , "a legitimate account? A:1 for yes. 0 for no."));
        return oo.getRequest(address(this), identifier, requestTime, ancillaryData).resolvedPrice;
    }

    /* * * * * * * * * */
    /* ADMIN FUNCTIONS */
    /* * * * * * * * * */

    /// @notice Withdraw funds from the contract.
    /// @param token Token to withdraw. @param amount Amount to withdraw.
    function withdrawFunds(ISuperToken token, uint256 amount) external {
        if (msg.sender != owner) revert Unauthorized();
        token.transfer(msg.sender, amount);
    }

    /// @notice Transfer ownership.
    function changeOwner(address _newOwner) external {
        if (msg.sender != owner) revert Unauthorized();
        owner = _newOwner;
    }
}