const { expect } = require("chai");
const { ethers } = require("hardhat");


/*
    We have separate gas tests as using a fixture doesn't work with hardhat-gas-reporter
*/

describe("Gas Tests", function () {
    let token, owner, addr1;

    before(async function () {
        const Puzzle = await ethers.getContractFactory("Puzzle");
        token = await Puzzle.deploy("uri");
        await token.deployed();
        await token.addPuzzle("test", 1, 0);

        [owner] = await ethers.getSigners();
    })

    it("Mint piece", async function () {
        await token.findPuzzlePieces(0, 1);
        expect(await token.balanceOf(owner.address)).to.equal(1);
    });

    it("Add puzzle", async function () {
        await expect(token.addPuzzle("test", 100, 0))
            .to.emit(token, 'NewPuzzleAdded')
            .withArgs(owner.address, 1);
    });

    it("Finish puzzle", async function () {
        await expect(token.finishPuzzle(0))
            .to.emit(token, "PuzzleFinished")
            .withArgs(owner.address, 0);
    });

});