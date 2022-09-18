// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "./ProofOfLoyalty.sol";
import {ISuperfluid} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

contract PoLFactory {

  // index of created contracts
  address[] public contracts;

  // useful to know the row count in contracts index
  function getContractCount() public returns(uint contractCount) {
    return contracts.length;
  }

  // deploy a new contract
  function newContract(ISuperfluid _host, address _owner, address _ooAddress) external returns(address newContract) {
    ProofOfLoyalty contract = new ProofOfLoyalty(_host, _owner, _ooAddress);
    contracts.push(contract);
    return contract;
  }
}
