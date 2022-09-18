const hre = require("hardhat")
const { Framework } = require("@superfluid-finance/sdk-core")
const { ethers } = require("hardhat")
require("dotenv").config()
const ProofOfLoyaltyABI =
    require("../artifacts/contracts/ProofOfLoyalty.sol/ProofOfLoyalty.json").abi

// run: npx hardhat run scripts/createFlowFromContract.js --network goerli
async function main() {
    // If this script is run directly using `node` you may want to call compile
    // manually to make sure everything is compiled
    // await hre.run('compile');

    //NOTE - make sure you add the address of the previously deployed money router contract on your network
    const proofOfLoyaltyAddress = "0xD880D4CdfFB17C530CF783544A9Af6Fa2ed8C55a"
    //add the address of your intended receiver
    const receiver = ""

    const provider = new hre.ethers.providers.JsonRpcProvider(
        process.env.GOERLI_URL
    )

    const sf = await Framework.create({
        chainId: (await provider.getNetwork()).chainId,
        provider
    })

    const signers = await hre.ethers.getSigners()

    const proofOfLoyalty = new ethers.Contract(
        proofOfLoyaltyAddress,
        ProofOfLoyaltyABI,
        provider
    )

    const daix = await sf.loadSuperToken("fDAIx")

    //call money router create flow into contract method from signers[0]
    //this flow rate is ~1000 tokens/month
    // await proofOfLoyalty
    //     .connect(signers[0])
    //     .createFlowFromContract(daix.address, receiver, "385802469135802")
    //     .then(function (tx) {
    //         console.log(`
    //     Congrats! You just successfully created a flow from the money router contract.
    //     Tx Hash: ${tx.hash}
    // `)
    //     })

    await proofOfLoyalty
        .connect(signers[0])
        .makeERC20SuperToken("0x07865c6e87b9f70255377e024ace6630c1eaa37f", 18, 2, "Super USDC","USDCx2")
        .then(function (tx) {
            console.log(`
        Congrats! You just successfully created a super token from the contract.
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
