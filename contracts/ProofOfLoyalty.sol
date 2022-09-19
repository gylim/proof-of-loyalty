// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {OptimisticOracleV2Interface} from "@uma/core/contracts/oracle/interfaces/OptimisticOracleV2Interface.sol";

import {ISuperfluid, ISuperToken, ISuperApp} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {ISuperfluidToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluidToken.sol";
import {ISuperTokenFactory} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperTokenFactory.sol";
import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import {CFAv1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";
import {IInstantDistributionAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IInstantDistributionAgreementV1.sol";
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
    int96 public flowRate;

    struct details {
        uint registerTime;
        uint endTime;
        string twitterHandle;
        bool blacklist;
    }
    mapping(address => details) public participantDetails;

    // for iterating to terminate stream on campaign completion
    address[] public participantList;

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

    /// @notice Optimistic Oracle Interface
    OptimisticOracleV2Interface public oo;
    bytes32 private identifier = bytes32("True or False"); // Use the yes no idetifier
    IERC20 public ooBond; // Use Görli WETH as the bond currency.
    uint256 public ooRewardAmt; // Bond reward
    uint256 public ooLiveness;

    constructor(ISuperfluid _host, address _owner, address _ooAddress) {
        assert(address(_host) != address(0));
        owner = _owner;

        // Initialise CFA Library
        cfaV1 = CFAv1Library.InitData(_host, IConstantFlowAgreementV1(
                address(_host.getAgreementClass(keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1")))));

        // Initialise Super Token Factory interface
        stf = ISuperTokenFactory(address(_host.getSuperTokenFactory()));

        // Initialise IDA library
        idaV1 = IDAv1Library.InitData(_host, IInstantDistributionAgreementV1(
                address(_host.getAgreementClass(keccak256("org.superfluid-finance.agreements.InstantDistributionAgreement.v1")))));

        // Initialise Optimistic Oracle interface
        oo = OptimisticOracleV2Interface(_ooAddress);
    }

    /* * * * * * * * * * * * * * * * */
    /* CAMPAIGN SUPERFLUID FUNCTIONS */
    /* * * * * * * * * * * * * * * * */

    /// @notice UTILITY FUNCTION Create SuperToken from ERC20 if none exists on current network, frontend will check list of existing SuperTokens
    function makeERC20SuperToken(IERC20 underlyingToken, uint8 underlyingDecimals,
        ISuperTokenFactory.Upgradability upgradability, string calldata name, string calldata symbol) external returns (ISuperToken superToken) {
            // assumes token being wrapped is the token to be used
            rewardToken = stf.createERC20Wrapper(underlyingToken, underlyingDecimals, upgradability, name, symbol);
            return rewardToken;
    }

    /// @notice UTILITY FUNCTION Wrap ERC20 to SuperTokens. @dev Requires ERC20 approve for superToken contract.
    function upgradeERC20SuperToken(ISuperToken superToken, uint amount) external {
        superToken.upgrade(amount);
    }

    /// @notice UTILITY FUNCTION Grant ERC20 approve
    function approveERC20(IERC20 token, address custodian, uint amount) external {
        (bool success, ) = address(token).call(abi.encodeWithSignature("approve(address,uint256)", custodian, amount));
        require(success, "ERC20 token approval failed");
    }

    /// @notice Send a lump sum of super tokens into the contract. @dev Requires superToken ERC20 approve for this contract
    /// @param _token Super Token to transfer. @param _amount Amount to transfer. @param _maxAmt reward per participant
    /// @param _startDate start of campaign, @param _endDate last day for subscribing, @param _duration length of campaign
    /// @param _oracleBond bond currency for oracle, @param _oracleReward reward for answering oracle
    /// @param _oracleLiveness time for challenges to oracle proposal
    function commenceCampaign(
        ISuperToken _token, uint _amount, uint _maxAmt,
        uint _startDate, uint _endDate, uint _duration,
        IERC20 _oracleBond, uint _oracleReward, uint _oracleLiveness,
    ) external {
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
        flowRate = SafeCast.toInt96(int(perParticipant / duration));
        ooRewardAmt = _oracleReward;
        ooLiveness = _oracleLiveness;
        ooBond = _oracleBond;
        // IDA activated for token after lumpsum transferred in
        rewardToken = _token;
        idaV1.createIndex(rewardToken, INDEX_ID);
    }

    /// @notice Self-help registration for airdrop/marketing campaign
    function subscribe(string calldata _twitterHandle) external {
        // check that campaign started, hasn't ended & there is still space for new registrants
        require(block.timestamp > startDate, "Campaign has yet to begin");
        require(block.timestamp < endDate, "Campaign has ended");
        require(numParticipants < maxParticipants, "Campaign is fully subscribed");
        require(particpantDetails[msg.sender].blacklist == false);
        cfaV1.createFlow(msg.sender, rewardToken, flowRate);
        // Get current units subscriber holds
        (, , uint256 currentUnitsHeld, ) = idaV1.getSubscription(rewardToken, address(this), INDEX_ID, msg.sender);
        // Update to current amount + 1
        idaV1.updateSubscriptionUnits(rewardToken, INDEX_ID, msg.sender, uint128(currentUnitsHeld + 1));
        // increment participants and record details
        numParticipants += 1;
        participantDetails[msg.sender].registerTime = block.timestamp;
        participantDetails[msg.sender].endTime = block.timestamp + duration;
        participantDetails[msg.sender].twitterHandle = _twitterHandle;
        participantList.push(msg.sender);
        // trigger UMA oracle to check if the user is real
        requestPrice(participantDetails[msg.sender].registerTime, participantDetails[msg.sender].twitterHandle);
    }

    /// @notice End flow for blacklisted users
    /// @param token Token to stop streaming. @param receiver Receiver of stream.
    function deleteSubscriber(address receiver) public {
        // if (msg.sender != owner) revert Unauthorized();
        cfaV1.deleteFlow(address(this), receiver, rewardToken);
        // remove shares of any leftover tokens
        idaV1.deleteSubscription(rewardToken, address(this), INDEX_ID, receiver);
        // delete from list of participants
        numParticipants -= 1;
        participantDetails[receiver].blacklist = true;
    }

    /// @notice FOR CHAINLINK KEEPERS. End flow for normal users
    function endSubscription() internal {
        // iterate through participants array
        for (uint i=0; i<participantList.length; i++) {
            address user = participantList[i];
            if (participantDetails[user].endTime >= block.timestamp
            && participantDetails[user].blacklist == false) {
                cfaV1.deleteFlow(address(this), user, rewardToken);
            }
        }
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
    function requestPrice(uint requestTime, string storage _userAccount) internal {
        bytes memory ancillaryData = bytes(string.concat("Q:Is user ", _userAccount , " a legitimate account? A:1 for yes. 0 for no."));
        // make request to Optimistic oracle
        oo.requestPrice(identifier, requestTime, ancillaryData, ooBond, ooRewardAmt);
        oo.setCustomLiveness(identifier, requestTime, ancillaryData, ooLiveness);
    }

    // Settle the request once it's gone through the liveness period. This acts to finalize the voted on outcome.
    function settleRequests(uint requestTime, string calldata  _userAccount) public {
        bytes memory ancillaryData = bytes(string.concat("Q:Is user ", _userAccount , " a legitimate account? A:1 for yes. 0 for no."));
        oo.settle(address(this), identifier, requestTime, ancillaryData);
    }

    // Fetch the resolved price from the Optimistic oracle that was settled.
    function getSettledPrice(uint requestTime, string calldata _userAccount) public view returns (int256) {
        bytes memory ancillaryData = bytes(string.concat("Q:Is user ", _userAccount , " a legitimate account? A:1 for yes. 0 for no."));
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
