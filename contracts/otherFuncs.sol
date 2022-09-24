// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISuperfluid, ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {ISuperTokenFactory} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperTokenFactory.sol";

contract ExtraStuff {

    ISuperTokenFactory public stf; // Super Token Factory

    constructor(ISuperfluid _host) {
        // Initialise Super Token Factory interface
        stf = ISuperTokenFactory(address(_host.getSuperTokenFactory()));
    }

    /// @notice UTILITY FUNCTION Create SuperToken from ERC20 if none exists on current network, frontend will check list of existing SuperTokens
    function makeERC20SuperToken(IERC20 underlyingToken, uint8 underlyingDecimals,
        ISuperTokenFactory.Upgradability upgradability, string calldata name, string calldata symbol) external returns (ISuperToken superToken) {
            // assumes token being wrapped is the token to be used
            return stf.createERC20Wrapper(underlyingToken, underlyingDecimals, upgradability, name, symbol);
    }

    /// @notice UTILITY FUNCTION Wrap ERC20 to SuperTokens. @dev Requires ERC20 approve for superToken contract.
    function upgradeERC20SuperToken(ISuperToken superToken, uint amount) external {
        superToken.upgrade(amount);
    }

    /// @notice UTILITY FUNCTION Grant ERC20 approve
    function approveERC20(address token, address custodian, uint amount) external {
        (bool success, ) = token.call(abi.encodeWithSignature("approve(address,uint256)", custodian, amount));
        require(success, "ERC20 token approval failed");
    }
}
