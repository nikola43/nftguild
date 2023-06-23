import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect, util } from 'chai';
import { Contract } from 'ethers';
import { formatEther, parseEther } from 'ethers/lib/utils';
import { ethers } from 'hardhat';
import { connectRouter, chains, connectFactory, connectPair, transferEth } from '../scripts/util';
const colors = require('colors');


import { MyToken, MyToken__factory, NFTGuild, NFTGuild__factory } from '../typechain'

//available functions
describe("Token contract", async () => {
    let deployer: SignerWithAddress;
    let bob: SignerWithAddress;
    let alice: SignerWithAddress;
    let nftGuild: NFTGuild;
    let myToken: MyToken;
    let router: Contract;
    const routerAddress = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
    const chainlinkDataFeeds = "0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e";
    const zeroAddress = "0x0000000000000000000000000000000000000000";

    it("1. Should get signer", async () => {
        const signers = await ethers.getSigners();
        deployer = signers[0];
        bob = signers[1];
        alice = signers[2];

        console.log(`${colors.cyan('Deployer Address')}: ${colors.yellow(deployer?.address)}`)
        console.log(`${colors.cyan('Bob Address')}: ${colors.yellow(bob?.address)}`)
        console.log(`${colors.cyan('Alice Address')}: ${colors.yellow(alice?.address)}`)

        expect(deployer?.address).to.not.be.undefined;
        expect(bob?.address).to.not.be.undefined;
        expect(alice?.address).to.not.be.undefined;
        expect(deployer?.address).not.be.eq(zeroAddress);
        expect(bob?.address).not.be.eq(zeroAddress);
        expect(alice?.address).not.be.eq(zeroAddress);
    });

    it("2. Should load router", async () => {
        router = await connectRouter()
        expect(router?.address).to.not.be.undefined;
        expect(router?.address).to.be.eq(routerAddress);
        expect(router?.address).not.be.eq(zeroAddress);
    });

    it("3. should Deploy token", async () => {
        myToken = await new MyToken__factory(deployer).deploy();
        await myToken.deployed();
        expect(myToken?.address).not.be.eq(zeroAddress);
        console.log(`${colors.cyan('NFTGuild Address')}: ${colors.yellow(myToken?.address)}`)
    });

    it("4. Should deploy NFTGuild", async () => {
        nftGuild = await new NFTGuild__factory(deployer).deploy(myToken.address, routerAddress, chainlinkDataFeeds);
        await nftGuild.deployed();
        expect(myToken?.address).not.be.eq(zeroAddress);
        console.log(`${colors.cyan('NFTGuild Address')}: ${colors.yellow(nftGuild?.address)}`)
    });

    it("5. Should add liquidity", async () => {
        await myToken.approve(chains.eth.router, ethers.constants.MaxUint256, { from: deployer?.address })
        const tokenAmount = parseEther("10000000")
        const ethAmount = parseEther("100")
        const tx = await router.connect(deployer).addLiquidityETH(
            myToken.address,
            tokenAmount,
            tokenAmount,
            ethAmount,
            deployer?.address,
            2648069985, // Saturday, 29 November 2053 22:59:45
            {
                value: ethAmount
            }
        )
        console.log(`${colors.cyan('TX')}: ${colors.yellow(tx.hash)}`)
        console.log()

        const routerFactory = await connectFactory();
        expect(routerFactory?.address).not.be.eq(zeroAddress);
        const pairAddress = await routerFactory.getPair(chains.eth.wChainCoin, myToken.address);
        expect(pairAddress).not.be.eq(zeroAddress);
        const pairContract = await connectPair(pairAddress);
        const pairBalance = await pairContract.balanceOf(deployer?.address);
        expect(pairBalance).not.be.eq(0);
        console.log(`${colors.cyan('LP Address')}: ${colors.yellow(pairContract?.address)}`)
        console.log(`${colors.cyan('LP Balance')}: ${colors.yellow(formatEther(await pairContract.balanceOf(deployer?.address)))}`)
        console.log()
    });
    
    it("7. Should return required eth amount for mint", async () => {
        const requiredEthAmount = await nftGuild.getRequiredEthAmount();
        expect(requiredEthAmount).not.be.eq(0);
        console.log(`${colors.cyan('Required Eth Amount')}: ${colors.yellow(formatEther(await requiredEthAmount))}`)
    });

    /*
    it("7. Should return required eth amount for mint", async () => {
        const requiredEthAmount = await nftGuild.getRequiredEthAmount();

        // check token supply
        console.log(`${colors.cyan('Required Eth Amount')}: ${colors.yellow(formatEther(await requiredEthAmount))}`)
    });
    

    it("7. buyBack", async () => {
        // transfer tokens to NFtGuild
        await transferEth(deployer, nftGuild.address, "10")

        // buyBack
        await nftGuild.buyBack({ from: deployer?.address })

        // check token supply
        console.log(`${colors.cyan('Token Supply')}: ${colors.yellow(formatEther(await myToken.totalSupply()))}`)
    });
    */
});