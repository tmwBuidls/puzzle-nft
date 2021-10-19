const { setup } = require("./utils.js");
const { expect } = require("chai");

describe("Contract", function () {
    let token, owner, addr1, addr2;

    beforeEach(async function() {
        ({ token, owner, addr1, addr2 } = await setup());
    });

    describe("Deployment", function () {
        it("Should set the right owner", async function () {
            // This test expects the owner variable stored in the contract to be correct
            expect(await token.owner()).to.equal(owner.address);
        });
    });

    describe("Transactions", function () {
        it("Should transfer tokens between accounts", async function () {
            await token.findPuzzlePieces(0, 1);

            // Need to do this because of how ethers.js handles overloading (See: https://github.com/ethers-io/ethers.js/issues/407#issuecomment-458329708)
            await token['safeTransferFrom(address,address,uint256)'](owner.address, addr1.address, 0)
            const addr1Balance = await token.balanceOf(addr1.address);
            expect(addr1Balance).to.equal(1);

            // We use .connect(addr) to send a transaction from another account
            await token.connect(addr1)['safeTransferFrom(address,address,uint256)'](addr1.address, addr2.address, 0);
            const addr2Balance = await token.balanceOf(addr2.address);
            expect(addr2Balance).to.equal(1);
        });

        it("Should fail if token does not exist", async function () {
            await expect(
                token.connect(addr1)['safeTransferFrom(address,address,uint256)'](addr1.address, owner.address, 0)
            ).to.be.revertedWith("ERC721: operator query for nonexistent token");

            // Owner balance shouldn't have changed.
            expect(await token.balanceOf(owner.address)).to.equal(0);
        });

        it("Should fail if does not own token", async function () {
            await token.findPuzzlePieces(0, 1);

            await expect(
                token.connect(addr1)['safeTransferFrom(address,address,uint256)'](addr1.address, owner.address, 0)
            ).to.be.revertedWith("ERC721: transfer caller is not owner nor approved");

            // Owner balance shouldn't have changed.
            expect(await token.balanceOf(owner.address)).to.equal(1);
        });
    });
})

