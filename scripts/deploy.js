const hre = require("hardhat")
const { Framework } = require("@superfluid-finance/sdk-core")
require("dotenv").config()

// Run: npx hardhat run scripts/deploy.js --network <network-name>
async function main() {
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    // await hre.run('compile');

    const provider = new hre.ethers.providers.JsonRpcProvider(
        process.env.GOERLI_URL
    )

    const sf = await Framework.create({
        chainId: (await provider.getNetwork()).chainId,
        provider
    })

    const signers = await hre.ethers.getSigners()
    // We get the contract to deploy
    const ProofOfLoyalty = await hre.ethers.getContractFactory("ProofOfLoyalty")
    //deploy the proof of loyalty contract
    const proofOfLoyalty = await ProofOfLoyalty.deploy(
        sf.settings.config.hostAddress,
        signers[0].address,
        "0xA5B9d8a0B0Fa04Ba71BDD68069661ED5C0848884" // Optimistic Oracle Goerli address
    )

    await proofOfLoyalty.deployed()

    console.log("Proof Of Loyalty deployed to:", proofOfLoyalty.address)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
    console.error(error)
    process.exitCode = 1
})
