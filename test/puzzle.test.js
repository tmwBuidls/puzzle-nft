const { expect } = require("chai");
const { setup } = require("./utils.js");
const { ethers } = require("hardhat");


describe("Puzzle", function () {
    let token, owner, addr1;

    beforeEach(async function () {
        ({ token, owner, addr1 } = await setup());
    });

    describe("Owner Functions", async function () {
        it("Should create a puzzle", async function () {
            await expect(token.addPuzzle("test", 100, 1))
                .to.emit(token, 'NewPuzzleAdded')
                .withArgs(owner.address, 1);
        });

        it("Should fail if non-owners add a puzzle", async function () {
            await expect(token.connect(addr1).addPuzzle("test", 100, 1))
                .to.revertedWith("Ownable: caller is not the owner");
        });

        it("Should update the puzzle price", async function() {
            await token.setPuzzlePrice(0, 1);
            expect(await token.puzzlePrice(0)).to.equal(1);
        });

        it("Should not update the puzzle price if not owner", async function() {
            await expect(token.connect(addr1).setPuzzlePrice(0, 1))
                .to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("Should update the sale status", async function() {
            await token.activatePuzzle(0, false);
            expect(await token.puzzleSaleActive(0)).to.equal(false);
        });

        it("Should not update the sale status if not owner", async function() {
            await expect(token.connect(addr1).activatePuzzle(0, false))
                .to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("Should update the max pieces", async function() {
            await token.setMaxPiecesPerOwner(1);
            expect(await token.maxPiecesPerOwner()).to.equal(1);
        });

        it("Should not update the max pieces if not owner", async function() {
            await expect(token.connect(addr1).setMaxPiecesPerOwner(1))
                .to.be.revertedWith("Ownable: caller is not the owner");
        });

    })

    describe("Minting", async function () {
        it("Should mint multiple", async function () {
            await token.findPuzzlePieces(0, 2);
            expect(await token.balanceOf(owner.address)).to.equal(2);
        });

        it("Should set tokenURI to baseURI + tokenId", async function() {
            const baseURI = "/this-puzzle/";
            await token.setBaseURI(baseURI);
    
            await token.findPuzzlePieces(0, 1);
            const tokenId = await token.totalSupply() - 1;    
            expect(await token.tokenURI(tokenId)).to.equal(baseURI + tokenId);
        });

        it("Should not mint if puzzle sale is not active", async function () {
            await token.activatePuzzle(0, false);
            await expect(token.findPuzzlePieces(0, 2))
                .to.be.revertedWith("Puzzle sale not active");
        });

        it("Should not mint if reached maximum for address", async function () {
            await token.findPuzzlePieces(0, 3);
            await expect(token.findPuzzlePieces(0, 2))
                .to.be.revertedWith("Cannot find more than 3 pieces");
        });

        it("Should not mint if no pieces available", async function () {
            await token.addPuzzle("test", 1, 0);
            await token.activatePuzzle(1, true);
            await expect(token.findPuzzlePieces(1, 2))
                .to.be.revertedWith("Exceeds the total pieces");
        });

        it("Should not mint if ether is too low", async function () {
            await token.addPuzzle("test", 100, 1);
            await token.activatePuzzle(1, true);
            await expect(token.findPuzzlePieces(1, 1), { value: ethers.utils.parseEther("0.5") })
                .to.be.revertedWith("Ether sent not correct");
        });

        it("Should not mint if puzzle does not exist", async function () {
            await expect(token.findPuzzlePieces(1, 3))
                .to.be.revertedWith("Puzzle does not exist");
        });

        it("Should not mint after puzzle has been finished", async function () {
            await token.addPuzzle("test", 1, 0);
            await token.activatePuzzle(1, true);
            await token.findPuzzlePieces(1, 1);
            await token.finishPuzzle(1);
            await expect(token.findPuzzlePieces(1, 1))
                .to.be.revertedWith("Puzzle has been finished");
        });

    });


    describe("Burning", async function () {
        it("Should burn pieces and mint puzzle if all are owned by address", async function () {
            const puzzleURI = "puzzleURI/"
            await token.addPuzzle(puzzleURI, 2, 0);
            await token.activatePuzzle(1, true);
            await token.findPuzzlePieces(1, 2);

            await expect(token.finishPuzzle(1))
                .to.emit(token, "PuzzleFinished")
                .withArgs(owner.address, 1);

            // Burns the two pieces and issues the final puzzle token.
            expect(await token.balanceOf(owner.address)).to.equal(1);

            // Token URI equals puzzle URI
            const tokenId = await token.totalSupply() - 1;
            expect(await token.tokenURI(tokenId)).to.equal(puzzleURI);
        });

        it("Should mint puzzle after token has been transferred to", async function () {
            // The puzzle has two pieces
            await token.addPuzzle("test", 2, 0);
            await token.activatePuzzle(1, true);

            // Owner has one piece
            await token.findPuzzlePieces(1, 1);

            // Addr1 has the other piece
            await token.connect(addr1).findPuzzlePieces(1, 1);
            const tokenId = await token.totalSupply() - 1;

            // Transfer Addr1 piece to Owner
            await token.connect(addr1)['safeTransferFrom(address,address,uint256)'](addr1.address, owner.address, tokenId);

            // Owner should now have all the pieces
            await expect(token.finishPuzzle(1))
                .to.emit(token, "PuzzleFinished")
                .withArgs(owner.address, 1);
        });

        it("Should not burn if not all pieces are owned by address", async function () {
            // The puzzle has two pieces
            await token.addPuzzle("test", 2, 0);
            await token.activatePuzzle(1, true);

            // Owner has one piece
            await token.findPuzzlePieces(1, 1);
            await expect(token.finishPuzzle(1))
                .to.be.revertedWith("Not collected all the pieces");

            // Addr1 has the other piece
            await token.connect(addr1).findPuzzlePieces(1, 1);
            await expect(token.finishPuzzle(1))
                .to.be.revertedWith("Not collected all the pieces");
        });

        it("Should not burn after token has been transferred away", async function () {
            // The puzzle has two pieces
            await token.addPuzzle("test", 2, 0);
            await token.activatePuzzle(1, true);

            // Owner starts with both pieces
            await token.findPuzzlePieces(1, 2);

            // Then we transfer one to another address
            const tokenId = await token.totalSupply() - 1;
            await token['safeTransferFrom(address,address,uint256)'](owner.address, addr1.address, tokenId);

            // Owner now does not have all the pieces
            await expect(token.finishPuzzle(1))
                .to.be.revertedWith("Not collected all the pieces");
        });

        it("Should not mint puzzle if already finished ", async function () {
            await token.addPuzzle("test", 2, 0);
            await token.activatePuzzle(1, true);
            await token.findPuzzlePieces(1, 2);
            await token.finishPuzzle(1);
            await expect(token.finishPuzzle(1))
                .to.be.revertedWith("Puzzle has been finished");

            // Burns the two pieces and issues the final puzzle token.
            expect(await token.balanceOf(owner.address)).to.equal(1);
        });
    });
});
