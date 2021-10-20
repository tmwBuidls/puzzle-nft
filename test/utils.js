const { loadFixture, deployContract } = require("ethereum-waffle");
const Puzzle = require('../artifacts/contracts/Puzzle.sol/Puzzle.json');

async function fixture([owner, addr1, addr2], provider) {
    const token = await deployContract(owner, Puzzle);
    return {token, owner, addr1, addr2};
}

async function setup() {
    const contract = await loadFixture(fixture);
    await contract.token.addPuzzle("test", 100, 0);
    return contract;
}

module.exports = {
    setup,
}