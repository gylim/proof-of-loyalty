const hre = require("hardhat")
const { Framework } = require("@superfluid-finance/sdk-core")
const { ethers } = require("hardhat")
require("dotenv").config()

// run: npx hardhat run scripts/upgradeERC20.js --network goerli
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

    const signers = await hre.ethers.getSigners();

    const superToken = await sf.loadSuperToken("0x0649cEc7f0EE517C7b422689cB9375b18B4AD3FA");
    const symbol = await superToken.symbol({providerOrSigner: provider});

    // approve amount tokens to superToken
    const stUpgrade = superToken.upgrade({
        amount: ethers.utils.parseEther("300000")
    });

    // print tx receipt
    await stUpgrade.exec(signers[0]).then(function (tx) {
        console.log(`You've just successfully upgraded 300000 ${symbol}.
        Tx Hash: ${tx.hash}`)
   })

}

main().catch(error => {
    console.error(error)
    process.exitCode = 1
})
