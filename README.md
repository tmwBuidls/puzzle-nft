# Puzzle NFT

An Ethereum contract where people can collect tokens (puzzle pieces) from different puzzles and then, once they have all the pieces, finish the puzzle by burning all the tokens of that puzzle and gaining the final full puzzle piece token.

Built using hardhat and waffle. My first attempt at a proper smart contract beyond tutorials. Still a lot to do/ improve on, most of which you can find in TODO.md.

## How does it work
- The owner adds however many puzzles that they like.
- Each puzzle has a URI, a number of pieces and a price per piece.
- An address chooses which puzzle to mint and how many pieces they want (up to a maximum ownership)
- Once an address has all the pieces they can try and finish the puzzle
- Finishing a puzzle, burns all the puzzle pieces and issues a final puzzle piece token with the puzzle URI.

## Some interesting bits of the contract

### Off-chain metadata
I wanted to do it on-chain but ultimately it's too expensive. To serve the puzzle piece token metadata we make use of the `_baseTokenURI` which we will set to some ipfs url (off-chain). Then use that to reference the metadata based off token id. For example: `ipfs://<ipfs-hash>/<token-id>`. However the final puzzle piece token can be **on-chain** with a Base64 encoded URI.

### Test Coverage
Due to my immutability paranoia, I've tried to have a lot of test coverage using waffle. 

In the tests I abstracted a bunch of setup into `test/utils.js` which loads the contract as a fixture and is then run in the `beforeEach()` function of the tests. `setup()` re-deploys the contract every time and adds the first puzzle. Therefore each test runs independently with a unique contract, but the fixture makes this performant.

Oh and another funny thing I learnt. I wanted to test token transferring, specifically using `_safeTransferFrom`; which is the recommended way to transfer tokens. However you can't reference that properly because of [how ethers.js handles overloading](https://github.com/ethers-io/ethers.js/issues/407#issuecomment-458329708). Therefore to test this you need to access the function like this `token['safeTransferFrom(address,address,uint256)']`.

### Contract Hooks
In `Puzzle.sol` I override the `_beforeTokenTransfer()` function. This is a hook that runs every time a token is transferred, minted or burned. I use this to ensure I update address to puzzle to token ownership, which I use to know whether an address has all the puzzle pieces.

I could put more in this function, specifically for burning and minting, but I thought it more confusing to have it here, rather than in the functions that handle that.

[Read more about hooks here.](https://docs.openzeppelin.com/contracts/3.x/extending-contracts#using-hooks)

## Commands
- To run: `npm run run`
- To deploy to Rinkeby: `npm run deploy`
- To test: `npm run test`