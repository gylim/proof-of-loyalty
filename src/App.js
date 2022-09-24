import React, { useEffect, useState } from "react";
import { Contract, ethers } from "ethers";
import PoLABI from "../artifacts/contracts/ProofOfLoyalty.sol/ProofOfLoyalty.json";
import addressList from "./addressList";
import Button from 'react-bootstrap/Button';
import "./App.css";
import CreateProject from "./components/CreateProject";

function App() {
  const [account, setAccount] = useState("");
  const [isWalletInstalled, setIsWalletInstalled] = useState(false);
  const [currentNetwork, setCurrentNetwork] = useState("");
  const [PoLContract, setPoLContract] = useState(null);
  const [isDeploying, setIsDeploying] = useState(false);

  const contractAddress = "0x9C3cF4D4Cb1D0476A871A49A4195E3351fffe5Bf";

  useEffect(() => {
    if (window.ethereum) {
      setIsWalletInstalled(true);
      setCurrentNetwork(window.ethereum.networkVersion);
    }
  }, []);



  useEffect(() => {
    function initPoL() {
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      const signer = provider.getSigner();
      setPoLContract(new Contract(contractAddress, PoLABI.abi, signer));
    }
    initPoL();
  }, [account]);

  async function connectWallet() {
    window.ethereum.request({ method: "eth_requestAccounts", })
      .then((accounts) => {
        setAccount(accounts[0])
        console.log(account)
      })
      .catch((error) => { alert("Something went wrong") });
  }

  // async function deployContract(owner) {
  //   setIsDeploying(true);
  //   try {
  //     const response = await PoLContract.newContract(addressList[currentNetwork].superfluidHost, owner, addressList[currentNetwork].uma);
  //     alert(`Proof-of-Loyalty successfully deployed to: ${response}`)
  //   } catch(err) {
  //     alert(err);
  //   } finally {
  //     setIsDeploying(false);
  //   }
  // }

  // if (account === "") {
  //   return (
  //     <>
  //       <div className='container'>
  //         <br />
  //         <h1>Proof of Loyalty</h1>
  //         <h2>Build a community of true fans</h2>
  //         <p>Reward your community with airdrops that vest linearly while weeding out bots and farm-and-dump behaviour</p>
  //         {isWalletInstalled ?
  //           (<Button onClick={connectWallet}>Connect Wallet</Button>) :
  //           (<p>Install MetaMask</p>)}
  //       </div>
  //     </>
  //   );
  // }

  return (
    <>
      <div className='container'>
        <br />
        {isWalletInstalled && !account ?
          (<Button onClick={connectWallet}>Connect Wallet</Button>) :
          (!account ? (<p>Install MetaMask</p>) : "")}
        <h1>Proof of Loyalty</h1>
        <h2>Build a community of true fans</h2>
        <p>Reward your community with airdrops that vest linearly while weeding out bots and farm-and-dump behaviour</p>
        <Button /* onClick={} */>
          Deploy new contract
        </Button>
        <p>Your current account is: {account}</p>
        <p>Your current network ID is: {currentNetwork}</p>

        <CreateProject polContract={PoLContract} account={account} />
      </div>

    </>
  );
}

export default App;
