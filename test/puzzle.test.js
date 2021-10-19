const { expect } = require("chai");
const { setup } = require("./utils.js");


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
    })



    describe("Minting", async function () {
        it("Should mint multiple", async function () {
            await token.findPuzzlePieces(0, 2);
            expect(await token.balanceOf(owner.address)).to.equal(2);
        });


        it("Should not mint if reached maximum for address", async function () {
            await token.findPuzzlePieces(0, 3);
            await expect(token.findPuzzlePieces(0, 2))
                .to.be.revertedWith("You cannot find more than 3 pieces");
        });

        it("Should not mint if no pieces available", async function () {
            await token.addPuzzle("test", 1, 1);
            await expect(token.findPuzzlePieces(1, 2))
                .to.be.revertedWith("This would exceed the total amount of pieces");
        });

        it("Should not mint if ether is too low");

        it("Should not mint if puzzle does not exist", async function () {
            await expect(token.findPuzzlePieces(1, 3))
                .to.be.revertedWith("Puzzle does not exist");
        });

        it("Should not mint after puzzle has been finished", async function () {
            await token.addPuzzle("test", 1, 1);
            await token.findPuzzlePieces(1, 1);
            await token.finishPuzzle(1);
            await expect(token.findPuzzlePieces(1, 1))
                .to.be.revertedWith("Puzzle has been finished");
        });

    });


    describe("Burning", async function () {
        it("Should burn pieces and mint puzzle if all are owned by address", async function () {
            await token.addPuzzle("test", 2, 1);
            await token.findPuzzlePieces(1, 2);

            await expect(token.finishPuzzle(1))
                .to.emit(token, "PuzzleFinished")
                .withArgs(owner.address, 1);

            // Burns the two pieces and issues the final puzzle token.
            expect(await token.balanceOf(owner.address)).to.equal(1);
        });

        it("Should mint puzzle after token has been transferred to", async function () {
            // The puzzle has two pieces
            await token.addPuzzle("test", 2, 1);

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
            await token.addPuzzle("test", 2, 1);

            // Owner has one piece
            await token.findPuzzlePieces(1, 1);
            await expect(token.finishPuzzle(1))
                .to.be.revertedWith("You have not collected all the pieces");

            // Addr1 has the other piece
            await token.connect(addr1).findPuzzlePieces(1, 1);
            await expect(token.finishPuzzle(1))
                .to.be.revertedWith("You have not collected all the pieces");
        });

        it("Should not burn after token has been transferred away", async function () {
            // The puzzle has two pieces
            await token.addPuzzle("test", 2, 1);

            // Owner starts with both pieces
            await token.findPuzzlePieces(1, 2);

            // Then we transfer one to another address
            const tokenId = await token.totalSupply() - 1;
            await token['safeTransferFrom(address,address,uint256)'](owner.address, addr1.address, tokenId);

            // Owner now does not have all the pieces
            await expect(token.finishPuzzle(1))
                .to.be.revertedWith("You have not collected all the pieces");
        });

        it("Should not mint puzzle if already finished ", async function () {
            await token.addPuzzle("test", 2, 1);
            await token.findPuzzlePieces(1, 2);
            await token.finishPuzzle(1);
            await expect(token.finishPuzzle(1))
                .to.be.revertedWith("Puzzle has been finished");

            // Burns the two pieces and issues the final puzzle token.
            expect(await token.balanceOf(owner.address)).to.equal(1);
        });
    });
});
