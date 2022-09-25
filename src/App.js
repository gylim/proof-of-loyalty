import React, { useEffect, useState } from "react";
import { Contract, ethers } from "ethers";
import PoLABI from "../artifacts/contracts/ProofOfLoyalty.sol/ProofOfLoyalty.json";
import addressList from "./addressList";
import Button from 'react-bootstrap/Button';
import "./App.css";
import CreateProject from "./components/CreateProject";
import { fetchApiCall } from "./helpers/apiController";

function App() {
  const [account, setAccount] = useState("");
  const [isWalletInstalled, setIsWalletInstalled] = useState(false);
  const [currentNetwork, setCurrentNetwork] = useState("");
  const [PoLContract, setPoLContract] = useState(null);
  const [isDeploying, setIsDeploying] = useState(false);
  const [projectsList, setProjectsList] = useState([]);
  const [endDate, setEndDate] = useState("");

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
    fetchProjects();
  }, [account]);

  async function connectWallet() {
    window.ethereum.request({ method: "eth_requestAccounts", })
      .then((accounts) => {
        setAccount(accounts[0])
        console.log(account)
      })
      .catch((error) => { alert("Something went wrong") });
  }

  const fetchProjects = async () => {
    // TODO: To call SmartContract to fetch all project pools(getAllProjects)
    const resData = await fetchApiCall("/project");
    if (resData.error) {
      notify(resData.msg);
      return;
    } // Has Error, Handled At Common Controller
    setProjectsList(resData);
    console.log("update projects list: ", projectsList);
  };

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
        <p>Your current account is: {account}</p>
        <p>Your current network ID is: {currentNetwork}</p>

        <CreateProject
          polContract={PoLContract}
          account={account}
          saved={() => {
            fetchProjects();
          }} />
        {JSON.stringify(projectsList)}
      </div>

    </>
  );
}

export default App;
