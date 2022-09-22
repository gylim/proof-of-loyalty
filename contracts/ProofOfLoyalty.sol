// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

import {OptimisticOracleV2Interface} from "@uma/core/contracts/oracle/interfaces/OptimisticOracleV2Interface.sol";

import {ISuperfluid, ISuperToken, ISuperApp} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {ISuperfluidToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluidToken.sol";
import {ISuperTokenFactory} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperTokenFactory.sol";
import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import {CFAv1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";
import {IInstantDistributionAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IInstantDistributionAgreementV1.sol";
import {IDAv1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/IDAv1Library.sol";

error Unauthorized();

contract ProofOfLoyalty is KeeperCompatibleInterface, VRFConsumerBaseV2 {

    using SafeCast for int96;

    address public owner;
    uint public startDate;
    uint public endDate;
    uint public duration;
    uint public perParticipant;
    uint public maxParticipants;
    uint public numParticipants;
    uint public participantIndex;
    uint private nextCheck;
    int96 public flowRate;

    struct details {
        uint64 index;
        uint registerTime;
        uint endTime;
        string twitterHandle;
        bool streamStatus;
        bool blacklist;
    }
    mapping(address => details) public participantDetails;
    address[] private participantList; // for iterating to terminate stream on campaign completion

    ISuperTokenFactory public stf; // Super Token Factory

    /// @notice CFA Library.
    using CFAv1Library for CFAv1Library.InitData;
    CFAv1Library.InitData public cfaV1;

    /// @notice IDA Library.
    using IDAv1Library for IDAv1Library.InitData;
    IDAv1Library.InitData public idaV1;
    uint32 public constant INDEX_ID = 0; // IDA index used for the ending distribution
    ISuperToken public rewardToken;

    /// @notice Optimistic Oracle Interface
    OptimisticOracleV2Interface public oo;
    bytes32 private identifier = bytes32("True or False"); // Use the yes no idetifier
    IERC20 public ooBond; // Use Görli WETH as the bond currency.
    uint256 public ooRewardAmt; // bond reward
    uint256 public ooLiveness; // challenge period

    /// @notice Chainlink VRF
    VRFCoordinatorV2Interface COORDINATOR;
    uint64 private subscriptionId;
    bytes32 private keyHash;
    uint32 callbackGasLimit = 50000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1;
    uint256 public randomNum;
    uint256 public requestId;

    constructor(
        ISuperfluid _host, address _owner, address _ooAddress,
        uint64 _subId, bytes32 _keyHash, address _vrfCoord) VRFConsumerBaseV2(_vrfCoord)
    {
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

        // Initialise VRF interface
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoord);
        subscriptionId = _subId;
        keyHash = _keyHash;
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
        require(_endDate >= _startDate + 86400, "End date must be at least 1 day after start");
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
        nextCheck = startDate + 86400;
        // IDA activated for token after lumpsum transferred in
        rewardToken = _token;
        idaV1.createIndex(rewardToken, INDEX_ID);
        // initiate first random word request
        requestRandomWords();
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
        participantDetails[msg.sender].index = participantIndex;
        participantDetails[msg.sender].registerTime = block.timestamp;
        participantDetails[msg.sender].endTime = block.timestamp + duration;
        participantDetails[msg.sender].twitterHandle = _twitterHandle;
        participantDetails[msg.sender].streamStatus = true;
        numParticipants += 1;
        participantIndex += 1;
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
        participantDetails[receiver].streamStatus = false;
        uint64 idx = participantDetails[receiver].index;
        delete participantList[idx];
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

    /* * * * * * * * *  */
    /* KEEPER FUNCTIONS */
    /*  * * * * * * * * */

    /// @notice FOR CHAINLINK KEEPERS. Find subscribers whose streams have ended
    function checkStreamEnd() public view returns (address[] memory) {
        address[] memory allPtcpts = participantList;
        address[] memory streamEnded = new address[](allPtcpts.length);
        uint count = 0;
        for (uint i=0; i<allPtcpts.length; i++) {
            address user = allPtcpts[i];
            if (user != address(0) &&
                participantDetails[user].streamStatus == true &&
                participantDetails[user].endTime >= block.timestamp
            ) {
                streamEnded[count] = user;
                count++;
            }
        }
        if (count != allPtcpts.length) {
            assembly {
                mstore(streamEnded, count)
            }
        }
        return streamEnded;
    }

    /// @notice FOR CHAINLINK KEEPERS. End flow for normal users
    function endSubscription(address[] memory streamEnded) public {
        // iterate through participants array
        for (uint i=0; i<streamEnded.length; i++) {
            address user = streamEnded[i];
            if (
                user != address(0) &&
                participantDetails[user].endTime >= block.timestamp &&
                participantDetails[user].streamStatus == true
            ) {
                cfaV1.deleteFlow(address(this), user, rewardToken);
                participantDetails[user].streamStatus = false;
            }
        }
    }

    function requestRandomWords() internal {
        requestId = COORDINATOR.requestRandomWords(keyHash, subscriptionId, requestConfirmations, callbackGasLimit, numWords);
    }

    function fulfillRandomWords(uint256 /* requestId */, uint256[] memory _randomNum) internal override {
        // find a random num between 1 and 24 hours
        randomNum = (_randomNum[0] % 86400) + 3600;
    }

    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory performData) {
        address[] memory streamEnded = checkStreamEnd();
        upkeepNeeded = streamEnded.length > 0 || block.timestamp >= nextCheck;
        performData = abi.encode(streamEnded);
        return (upkeepeNeeded, performData);
    }

    function performUpkeep(bytes calldata performData) external override {
        if (block.timestamp >= nextCheck) {
            nextCheck += randomNum;
            requestRandomWords();
        } else {
            address[] memory streamEnded = abi.decode(performData, (address[]));
            endSubscription(streamEnded);
        }
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
