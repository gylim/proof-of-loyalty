const hre = require("hardhat")
const { Framework } = require("@superfluid-finance/sdk-core")
require("dotenv").config()

// Run: npx hardhat run scripts/deploy.js --network <network-name>
async function main() {

    const provider = new hre.ethers.providers.JsonRpcProvider(
        process.env.GOERLI_URL
    )

    const sf = await Framework.create({
        chainId: (await provider.getNetwork()).chainId,
        provider
    })

    const [signer] = await hre.ethers.getSigners()
    console.log('Deploying contract with account: ', signer.address);

    const contract = await hre.ethers.getContractFactory("ProofOfLoyalty")
    const newContract = await contract.deploy(
        sf.settings.config.hostAddress,
        signer.address,
        "0xA5B9d8a0B0Fa04Ba71BDD68069661ED5C0848884", // Optimistic Oracle Goerli address
        2315,
        "0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15",
        "0x2ca8e0c643bde4c2e08ab1fa0da3401adad7734d"
    )

    await newContract.deployed()

    console.log("Contract deployed to:", newContract.address)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
    console.error(error)
    process.exitCode = 1
})
