// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ISuperfluid, ISuperToken, ISuperApp} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {ISuperfluidToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluidToken.sol";
import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import {ISuperTokenFactory} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperTokenFactory.sol";
import {CFAv1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";

error Unauthorized();

contract ProofOfLoyalty {
    /// @notice Owner.
    address public owner;

    /// @notice CFA Library.
    using CFAv1Library for CFAv1Library.InitData;
    CFAv1Library.InitData public cfaV1;

    /// @notice Super Token Factory
    ISuperTokenFactory public stf;

    constructor(ISuperfluid host, address _owner) {
        assert(address(host) != address(0));
        owner = _owner;

        // Initialize CFA Library
        cfaV1 = CFAv1Library.InitData(host, IConstantFlowAgreementV1(
                address(host.getAgreementClass(keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1")))
            )
        );

        // Initialize Super Token Factory interface
        stf = ISuperTokenFactory(address(host.getSuperTokenFactory()));
    }

    /// @notice Create SuperToken from ERC20 if none exists on current network
    function makeERC20SuperToken(IERC20 underlyingToken, uint8 underlyingDecimals,
        Upgradability upgradability, string calldata name, string calldata symbol)
        returns (ISuperToken superToken) {
            // check if superToken exists and return the token, otherwise create the wrapper
            if (/* supertoken exists */) return; // function for superToken
            else return stf.createERC20Wrapper(underlyingToken, underlyingDecimals, upgradability, name, symbol);
    }

    /// @notice Transfer ownership.
    function changeOwner(address _newOwner) external {
        if (msg.sender != owner) revert Unauthorized();
        owner = _newOwner;
    }

    /// @notice Send a lump sum of super tokens into the contract. @dev This requires a super token ERC20 approval.
    /// @param token Super Token to transfer. @param amount Amount to transfer.
    function sendLumpSumToContract(ISuperToken token, uint256 amount) external {
        if (msg.sender != owner) revert Unauthorized();
        token.transferFrom(msg.sender, address(this), amount);
    }

    /// @notice Create flow from contract to specified address.
    /// @param token Token to stream. @param receiver Receiver of stream. @param flowRate Flow rate per second to stream.
    function createFlowFromContract(ISuperfluidToken token, address receiver, int96 flowRate) external {
        if (msg.sender != owner) revert Unauthorized();
        cfaV1.createFlow(receiver, token, flowRate);
    }

    /// @notice Update flow from contract to specified address.
    /// @param token Token to stream. @param receiver Receiver of stream. @param flowRate Flow rate per second to stream.
    function updateFlowFromContract(ISuperfluidToken token, address receiver, int96 flowRate) external {
        if (msg.sender != owner) revert Unauthorized();
        cfaV1.updateFlow(receiver, token, flowRate);
    }

    /// @notice Delete flow from contract to specified address.
    /// @param token Token to stop streaming. @param receiver Receiver of stream.
    function deleteFlowFromContract(ISuperfluidToken token, address receiver) external {
        if (msg.sender != owner) revert Unauthorized();
        cfaV1.deleteFlow(address(this), receiver, token);
    }

    /// @notice Withdraw funds from the contract.
    /// @param token Token to withdraw. @param amount Amount to withdraw.
    function withdrawFunds(ISuperToken token, uint256 amount) external {
        if (msg.sender != owner) revert Unauthorized();
        token.transfer(msg.sender, amount);
    }
}
