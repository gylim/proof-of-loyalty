const hre = require("hardhat")
const { Framework } = require("@superfluid-finance/sdk-core")
const { ethers } = require("hardhat")
require("dotenv").config()
const ProofOfLoyaltyABI =
    require("../artifacts/contracts/ProofOfLoyalty.sol/ProofOfLoyalty.json").abi

//to run this script:
//1) Needs: .env file, network and accounts specified in hardhat.config.js
//   address of your own contract
//2) Run: npx hardhat run scripts/aclApproval.js --network goerli
async function main() {
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    // await hre.run('compile');

    //NOTE - add the address of the previously deployed money router contract on your network
    const ProofLoyaltyAddress = "0xD880D4CdfFB17C530CF783544A9Af6Fa2ed8C55a"

    const provider = new hre.ethers.providers.JsonRpcProvider(
        process.env.GOERLI_URL
    )

    const sf = await Framework.create({
        chainId: (await provider.getNetwork()).chainId,
        provider
    })

    const signers = await hre.ethers.getSigners()

    const proofOfLoyalty = new ethers.Contract(
        ProofLoyaltyAddress,
        ProofOfLoyaltyABI,
        provider
    )

    const daix = await sf.loadSuperToken("fDAIx")

    //approve contract to spend 1000 daix
    const aclApproval = sf.cfaV1.updateFlowOperatorPermissions({
        flowOperator: proofOfLoyalty.address,
        superToken: daix.address,
        flowRateAllowance: "3858024691358024", //10k tokens per month in flowRateAllowanace
        permissions: 7 //NOTE: this allows for full create, update, and delete permissions. Change this if you want more granular permissioning
    })
    await aclApproval.exec(signers[0]).then(function (tx) {
        console.log(`
        Congrats! You've just successfully made the proof of loyalty contract a flow operator.
        Tx Hash: ${tx.hash}
    `)
    })
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
    console.error(error)
    process.exitCode = 1
})
