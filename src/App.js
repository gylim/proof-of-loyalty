import React, { useEffect, useState } from "react";
import { Contract, ethers } from "ethers";
import PoLFactoryABI from "../artifacts/contracts/PoLFactory.sol";
import addressList from "./addressList";
import "./App.css";

function App () {
  const [account, setAccount] = useState("");
  const [isWalletInstalled, setIsWalletInstalled] = useState(false);
  const [currentNetwork, setCurrentNetwork] = useState("");
  const [contractAddress, setContractAddress] = useState("");
  const [PoLFactoryContract, setPoLFactoryContract] = useState(null);
  const [isDeploying, setIsDeploying] = useState(false);

  useEffect(() => {
    if (window.ethereum) {
      setIsWalletInstalled(true);
      setCurrentNetwork(window.ethereum.networkVersion);
    }
  }, []);



  useEffect(() => {
    function initPoLFactory() {
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      const signer = provider.getSigner();
      setPoLFactoryContract(new Contract(contractAddress, PoLFactoryABI.abi, signer));
    }
    initPoLFactory();
  }, [account]);

  async function connectWallet() {
    window.ethereum.request({method: "eth_requestAccounts",})
    .then((accounts) => {
      setAccount(accounts[0])
      console.log(account)
    })
    .catch((error) => {alert("Something went wrong")});
  }

  async function deployContract(owner) {
    setIsDeploying(true);
    try {
      const response = await PoLFactoryContract.newContract(addressList[currentNetwork].superfluidHost, owner, addressList[currentNetwork].uma);
      alert(`Proof-of-Loyalty successfully deployed to: ${response}`)
    } catch(err) {
      alert(err);
    } finally {
      setIsDeploying(false);
    }
  }

  if (account === "") {
    return (
      <>
        <div className='container'>
          <br/>
          <h1>Proof of Loyalty</h1>
          <h2>Build a community of true fans</h2>
          <p>Reward your community with airdrops that vest linearly while weeding out bots and farm-and-dump behaviour</p>
          {isWalletInstalled ?
          (<button onClick={connectWallet}>Connect Wallet</button>) :
          (<p>Install MetaMask</p>)}
        </div>
      </>
    );
  }

  return(
    <>
        <div className='container'>
          <br/>
          <h1>Proof of Loyalty</h1>
          <h2>Build a community of true fans</h2>
          <p>Reward your community with airdrops that vest linearly while weeding out bots and farm-and-dump behaviour</p>
          <button onClick={() => {deployContract()}}>
            Deploy new contract
          </button>
        </div>
      </>
  );
}

export default App;
