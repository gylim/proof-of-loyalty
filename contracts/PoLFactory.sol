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
  function deployNewContract(
      ISuperfluid _host, address _owner, address _ooAddress,
      uint64 _subId, bytes32 _keyHash, address _vrfCoord
    ) external returns(address newContract) {
        ProofOfLoyalty pol = new ProofOfLoyalty(_host, _owner, _ooAddress, _subId, _keyHash, _vrfCoord);
        contracts.push(address(pol));
        return address(pol);
  }
}
