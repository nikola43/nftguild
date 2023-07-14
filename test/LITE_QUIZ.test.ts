import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from 'hardhat';
const colors = require('colors');

import { LITE_QUIZ } from '../typechain';
import { expect } from 'chai';
import { transferEth } from '../scripts/util';

//available functions
describe("Token contract", async () => {
    let deployer: SignerWithAddress;
    let bob: SignerWithAddress;
    let alice: SignerWithAddress;
    let QUIZ: LITE_QUIZ;


    it("1. Get Signer", async () => {
        const signers = await ethers.getSigners();
        deployer = signers[0];
        bob = signers[1];
        alice = signers[2];

        console.log(`${colors.cyan('Deployer Address')}: ${colors.yellow(deployer?.address)}`)
        console.log(`${colors.cyan('Bob Address')}: ${colors.yellow(bob?.address)}`)
        console.log(`${colors.cyan('Alice Address')}: ${colors.yellow(alice?.address)}`)
    });

    it("2. Load router", async () => {
        QUIZ = await ethers.getContractAt("LITE_QUIZ", "0xaa9EcE1a291e9F62DCd6cF91822dDF073E7Bbcf9")
        const slot0Bytes = await ethers.provider.getStorageAt(QUIZ.address, 0);
        const slot1Bytes = await ethers.provider.getStorageAt(QUIZ.address, 1);
        const slot2Bytes = await ethers.provider.getStorageAt(QUIZ.address, 2);

        console.log(`${colors.cyan('Slot 0')}: ${colors.yellow(slot0Bytes)}`)
        console.log(`${colors.cyan('Slot 1')}: ${colors.yellow(slot1Bytes)}`)
        console.log(`${colors.cyan('Slot 2')}: ${colors.yellow(slot2Bytes)}`)

        // convert bytes to human readable
        const slot0 = ethers.utils.hexStripZeros(slot0Bytes)
        const slot1 = ethers.utils.hexStripZeros(slot1Bytes)
        const slot2 = ethers.utils.hexStripZeros(slot2Bytes)
        console.log(`${colors.cyan('Slot 0')}: ${colors.yellow(slot0)}`)
        console.log(`${colors.cyan('Slot 1')}: ${colors.yellow(slot1)}`)
        console.log(`${colors.cyan('Slot 0')}: ${colors.yellow(slot2)}`)

        //let y = ethers.utils.defaultAbiCoder.decode(["string"], slot1Bytes)
        ///console.log(y)



        await QUIZ.Try(' letteR W ', { from: deployer?.address, value: ethers.utils.parseEther("1.1") })
        expect(1).to.equal(1)

        // await transferEth(deployer, QUIZ.address, "1")

        // check contract balance
        const balance = await ethers.provider.getBalance(QUIZ.address)
        console.log(`${colors.cyan('Contract Balance')}: ${colors.yellow(ethers.utils.formatEther(balance))}`)
    });
});