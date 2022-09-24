// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import '@chainlink/contracts/src/v0.8/ChainlinkClient.sol';

import "../utils/strings.sol";

import {OptimisticOracleV2Interface} from "@uma/core/contracts/oracle/interfaces/OptimisticOracleV2Interface.sol";

import {ISuperfluid, ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {ISuperfluidToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluidToken.sol";
import {ISuperTokenFactory} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperTokenFactory.sol";
import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import {CFAv1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";

error Unauthorized();

contract ProofOfLoyalty is KeeperCompatibleInterface, VRFConsumerBaseV2, ChainlinkClient {

    using SafeCast for int96;
    using strings for *;

    address public owner;
    string public campaignHandle;
    uint public startDate;
    uint public endDate;
    uint public duration;
    uint public perParticipant;
    uint public maxParticipants;
    uint public numParticipants;
    uint64 public participantIndex;
    uint public nextCheck; // to change to private for actual
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
    address[] public participantList; // to change to private for actual
    mapping(string => address) public twitterToAddress;

    /// @notice CFA Library.
    using CFAv1Library for CFAv1Library.InitData;
    CFAv1Library.InitData public cfaV1;

    ISuperToken public rewardToken;

    /// @notice Optimistic Oracle Interface
    OptimisticOracleV2Interface public oo;
    bytes32 private identifier = bytes32("YES_OR_NO_QUERY"); // Use the yes no idetifier
    IERC20 public ooBond; // ERC20 for oracle reward
    uint256 public ooRewardAmt; // oracle reward amount
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

    /// @notice Chainlink API
    using Chainlink for Chainlink.Request;
    string public id;
    bytes32 private jobId;
    uint256 private fee;
    event RequestFirstId(bytes32 indexed requestId, string id);

    constructor(
        ISuperfluid _host, address _owner, address _ooAddress ,
        uint64 _subId, bytes32 _keyHash, address _vrfCoord) VRFConsumerBaseV2(_vrfCoord)
    {
        assert(address(_host) != address(0));
        owner = _owner;

        // Initialise CFA Library
        cfaV1 = CFAv1Library.InitData(_host, IConstantFlowAgreementV1(
                address(_host.getAgreementClass(keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1")))));

        // Initialise Optimistic Oracle interface
        oo = OptimisticOracleV2Interface(_ooAddress);

        // Initialise VRF interface
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoord);
        subscriptionId = _subId;
        keyHash = _keyHash;

        // Initialise oracle and token for api
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
        setChainlinkOracle(0xCC79157eb46F5624204f47AB42b3906cAA40eaB7);
        jobId = '7d80a6386ef543a3abb52817f6707e3b';
        fee = (1 * LINK_DIVISIBILITY) / 10;
    }

    /* * * * * * * * * * * * * * * * */
    /* CAMPAIGN SUPERFLUID FUNCTIONS */
    /* * * * * * * * * * * * * * * * */

    /// @notice Send a lump sum of super tokens into the contract. @dev Requires superToken ERC20 approve for this contract
    /// @param _token Super Token to transfer. @param _amount Amount to transfer. @param _maxAmt reward per participant
    /// @param _startDate start of campaign, @param _endDate last day for subscribing, @param _duration length of campaign
    /// @param _oracleBond bond currency for oracle, @param _oracleReward reward for answering oracle
    /// @param _oracleLiveness time for challenges to oracle proposal
    function commenceCampaign(
        ISuperToken _token, uint _amount, uint _maxAmt,
        uint _startDate, uint _endDate, uint _duration,
        IERC20 _oracleBond, uint _oracleReward, uint _oracleLiveness,
        string calldata _campaignHandle
    ) external {
        require(_endDate >= _startDate + 600, "End date must be at least 1 day after start"); // change to 86400 for actual
        if (msg.sender != owner) revert Unauthorized();
        // Deposit reward
        _token.transferFrom(msg.sender, address(this), _amount);
        // Initialise parameters of campaign, calculate flow rate
        campaignHandle = _campaignHandle;
        perParticipant = _maxAmt;
        maxParticipants = _amount / _maxAmt;
        startDate = _startDate;
        endDate = _endDate;
        duration = _duration;
        flowRate = SafeCast.toInt96(int(perParticipant / duration));
        ooRewardAmt = _oracleReward;
        ooLiveness = _oracleLiveness;
        ooBond = _oracleBond;
        nextCheck = startDate + 300;
        rewardToken = _token;
        // initiate first random word request
        requestRandomWords();
    }

    /// @notice Self-help registration for airdrop/marketing campaign
    function subscribe(string calldata _twitterHandle) external {
        // check that campaign started, hasn't ended & there is still space for new registrants
        require(block.timestamp > startDate, "Campaign has yet to begin");
        require(block.timestamp < endDate, "Campaign has ended");
        require(numParticipants < maxParticipants, "Campaign is fully subscribed");
        require(participantDetails[msg.sender].blacklist == false);
        cfaV1.createFlow(msg.sender, rewardToken, flowRate);
        // increment participants and record details
        participantDetails[msg.sender].index = participantIndex;
        participantDetails[msg.sender].registerTime = block.timestamp;
        participantDetails[msg.sender].endTime = block.timestamp + duration;
        participantDetails[msg.sender].twitterHandle = _twitterHandle;
        participantDetails[msg.sender].streamStatus = true;
        twitterToAddress[_twitterHandle] = msg.sender;
        numParticipants += 1;
        participantIndex += 1;
        participantList.push(msg.sender);
        // trigger UMA oracle to check if the user is real
        requestPrice(participantDetails[msg.sender].registerTime, participantDetails[msg.sender].twitterHandle);
    }

    /// @notice End flow for blacklisted users
    /// @param receiver Receiver of stream.
    function deleteSubscriber(address receiver) public {
        // if (msg.sender != owner) revert Unauthorized();
        cfaV1.deleteFlow(address(this), receiver, rewardToken);
        // delete from list of participants
        numParticipants -= 1;
        participantDetails[receiver].blacklist = true;
        participantDetails[receiver].streamStatus = false;
        uint64 idx = participantDetails[receiver].index;
        delete participantList[idx];
    }

    /*  * * * * * * * * * * */
    /* UMA ORACLE FUNCTIONS */
    /* * * * * * * * * *  * */

    // Submit a data request to the Optimistic oracle.
    function requestPrice(uint requestTime, string storage _twitterHandle) internal {
        bytes memory _ancData = bytes(string.concat("Q:Is user @", _twitterHandle , " a legitimate account? A:1 for yes. 0 for no."));
        // make request to Optimistic oracle
        oo.requestPrice(identifier, requestTime, _ancData, ooBond, ooRewardAmt);
        oo.setCustomLiveness(identifier, requestTime, _ancData, ooLiveness);
    }

    // Settle the request once it's gone through the liveness period. This acts to finalize the voted on outcome.
    function settleRequests(uint requestTime, string calldata _twitterHandle) public {
        bytes memory _ancData = bytes(string.concat("Q:Is user @", _twitterHandle , " a legitimate account? A:1 for yes. 0 for no."));
        oo.settle(address(this), identifier, requestTime, _ancData);
    }

    // Fetch the resolved price from Optimistic oracle and kick fake users.
    function getResultAndDelete(uint requestTime, string calldata _twitterHandle) public {
        bytes memory _ancData = bytes(string.concat("Q:Is user @", _twitterHandle , " a legitimate account? A:1 for yes. 0 for no."));
        int256 outcome = oo.getRequest(address(this), identifier, requestTime, _ancData).resolvedPrice;
        if (outcome == int256(1)) {
            address faker = twitterToAddress[_twitterHandle];
            deleteSubscriber(faker);
        }
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

    /// @notice VRF to get random number for time of check
    function requestRandomWords() internal {
        requestId = COORDINATOR.requestRandomWords(keyHash, subscriptionId, requestConfirmations, callbackGasLimit, numWords);
    }

    /// @notice VRF to callback when number is ready
    function fulfillRandomWords(uint256 /* requestId */, uint256[] memory _randomNum) internal override {
        // find a random num between 1 and 24 hours
        // randomNum = (_randomNum[0] % 86400) + 3600;
        // find a random num between 5 and 10 min
        randomNum = (_randomNum[0] % 600) + 300;
    }

    /// @notice Connect API function to call DB linked fn
    function requestFirstId() public returns (bytes32 _requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
        // replace url with mongo connected one
        req.add('get', string(bytes.concat('https://nodeproofofloyalty.herokuapp.com/twitterapi/getunmatched?handle=', campaignHandle)));
        req.add('path', 'name');
        // Sends the request
        return sendChainlinkRequest(req, fee);
    }

    /// @notice Connect API fulfill function
    function fulfill(bytes32 _requestId, string memory _id) public recordChainlinkFulfillment(_requestId) {
        emit RequestFirstId(_requestId, _id);
        id = _id;
        strings.slice memory s = id.toSlice();
        strings.slice memory delim = ",".toSlice();
        string[] memory parts = new string[](s.count(delim) + 1);
        for (uint i=0; i<parts.length; i++) {
            parts[i] = s.split(delim).toString();
            deleteSubscriber(twitterToAddress[parts[i]]);
        }
    }

    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory performData) {
        if (block.timestamp >= nextCheck && nextCheck >= 0) {
            return (true, '');
        } else {
            address[] memory streamEnded = checkStreamEnd();
            // upkeepNeeded = streamEnded.length > 0;
            // performData = abi.encode(streamEnded);
            return (streamEnded.length > 0, abi.encode(streamEnded));
        }
    }

    function performUpkeep(bytes calldata performData) external override {
        if (block.timestamp >= nextCheck && nextCheck >= 0) {
            nextCheck += randomNum;
            requestRandomWords();
            // call twitter and get response
            requestFirstId();
        } else {
            // address[] memory streamEnded = abi.decode(performData, (address[]));
            endSubscription(abi.decode(performData, (address[])));
        }
    }

    /* * * * * * * * * */
    /* ADMIN FUNCTIONS */
    /* * * * * * * * * */

    /// @notice Withdraw supertokens from the contract.
    /// @param token Token to withdraw. @param amount Amount to withdraw.
    function withdrawFunds(ISuperToken token, uint256 amount) external {
        if (msg.sender != owner) revert Unauthorized();
        token.transfer(msg.sender, amount);
    }

    /// @notice Withdraw link from contract.
    function withdrawLink() external {
        if (msg.sender != owner) revert Unauthorized();
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(msg.sender, link.balanceOf(address(this))), 'Unable to transfer');
    }

    /// @notice Transfer ownership.
    function changeOwner(address _newOwner) external {
        if (msg.sender != owner) revert Unauthorized();
        owner = _newOwner;
    }
}
