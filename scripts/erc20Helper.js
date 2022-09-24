const hre = require("hardhat")
const { Framework } = require("@superfluid-finance/sdk-core")
const { ethers } = require("hardhat")
require("dotenv").config()

// run: npx hardhat run scripts/erc20Helper.js --network goerli
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
    const stApprove = superToken.approve({
        receiver: "0x96046328135f3aFC46cC8a82CA9E472f5cE1E2Ff", //
        amount: ethers.utils.parseEther("300000")
    });

    // print tx receipt
    await stApprove.exec(signers[0]).then(function (tx) {
        console.log(`You've just successfully approved the address to spend 50 ${symbol}.
        Tx Hash: ${tx.hash}`)
   })

    // check allowance of superToken
    await superToken.allowance({
        owner: signers[0].address,
        spender: "0x9c3cf4d4cb1d0476a871a49a4195e3351fffe5bf",
        providerOrSigner: provider
    }).then((res) => {
        console.log(`The allowance for the spender is ${res}`)
    })

}

main().catch(error => {
    console.error(error)
    process.exitCode = 1
})
