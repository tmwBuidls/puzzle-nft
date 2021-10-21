// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Puzzle is ERC721, Ownable {
    // Counter for token IDs
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    string private _baseTokenURI;
    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    uint256 public maxPiecesPerOwner = 3;
    // Final puzzle URIs
    string[] private _puzzleURIs;
    mapping(uint256 => bool) public puzzleFinished;
    mapping(uint256 => bool) public puzzleSaleActive;
    mapping(uint256 => uint256) public puzzlePrice;
    mapping(uint256 => uint256) public totalPuzzlePieces;
    mapping(uint256 => uint256[]) public puzzleToPiece;
    mapping(uint256 => uint256) public pieceToPuzzle;
    // How many pieces someone owns by puzzle
    mapping(address => mapping(uint256 => uint256)) private _ownedPuzzlePieces;

    // Events
    event NewPuzzlePieceFound(address sender, uint256 puzzle, uint256 tokenId);
    event PuzzleFinished(address sender, uint256 puzzleId);
    event NewPuzzleAdded(address sender, uint256 puzzleId);

    constructor(string memory baseURI) ERC721("Puzzle", "PIECE") {
        setBaseURI(baseURI);
    }

    /**
     * @dev Main minting function.
     * Takes a `puzzleId` and a `num` of tokens to mint.
     */
    function findPuzzlePieces(uint256 puzzleId, uint256 num) public payable {
        require(puzzleId < _puzzleURIs.length, "Puzzle does not exist");
        require(puzzleSaleActive[puzzleId] == true, "Puzzle sale not active");
        require(puzzleFinished[puzzleId] != true, "Puzzle has been finished");
        require(
            puzzleToPiece[puzzleId].length + num <= totalPuzzlePieces[puzzleId],
            "Exceeds the total pieces"
        );
        require(
            msg.value >= puzzlePrice[puzzleId] * num,
            "Ether sent not correct"
        );

        // Get how many pieces this address owns
        uint256 balance = _ownedPuzzlePieces[msg.sender][puzzleId];
        require(
            balance + num <= maxPiecesPerOwner,
            "Cannot find more than 3 pieces"
        );

        // Get the current tokenId.
        uint256 newItemId = _tokenIds.current();

        for (uint256 i; i < num; i++) {
            uint256 tokenId = newItemId + i;

            // Map the token to puzzle and then mint
            pieceToPuzzle[tokenId] = puzzleId;
            puzzleToPiece[puzzleId].push(tokenId);
            _safeMint(msg.sender, tokenId);

            // Increment the counter for when the next NFT is minted.
            _tokenIds.increment();

            emit NewPuzzlePieceFound(msg.sender, puzzleId, tokenId);
        }
    }

    /**
     * @dev Main burning function.
     * Takes a `puzzleId` and checks whether the sender has all the pieces.
     * If they do:
     * - Burns all that puzzle's tokens.
     * - Mints the final full puzzle.
     */
    function finishPuzzle(uint256 puzzleId) public {
        require(puzzleFinished[puzzleId] != true, "Puzzle has been finished");
        uint256 balance = _ownedPuzzlePieces[msg.sender][puzzleId];
        require(
            balance == totalPuzzlePieces[puzzleId],
            "Not collected all the pieces"
        );

        // Burn all the puzzle pieces of the owner
        for (uint256 i; i < balance; i++) {
            uint256 tokenId = puzzleToPiece[puzzleId][i];
            _burn(tokenId);
        }

        puzzleFinished[puzzleId] = true;

        // Issue the final puzzle
        uint256 newItemId = _tokenIds.current();
        _safeMint(msg.sender, newItemId);
        setTokenURI(newItemId, _puzzleURIs[puzzleId]);
        _tokenIds.increment();

        emit PuzzleFinished(msg.sender, puzzleId);
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIds.current();
    }

    function myPuzzlePieces(uint256 puzzleId) public view returns (uint256) {
        return _ownedPuzzlePieces[msg.sender][puzzleId];
    }

    // onlyOwner ---------------------------

    function addPuzzle(
        string memory puzzleURI,
        uint256 puzzlePieces,
        uint256 price
    ) public onlyOwner {
        // Add puzzle URI and get the id
        _puzzleURIs.push(puzzleURI);
        uint256 puzzleId = _puzzleURIs.length - 1;

        // Set the total puzzle pieces and price
        totalPuzzlePieces[puzzleId] = puzzlePieces;
        puzzlePrice[puzzleId] = price;

        emit NewPuzzleAdded(msg.sender, puzzleId);
    }

    function activatePuzzle(uint256 puzzleId, bool status) public onlyOwner {
        puzzleSaleActive[puzzleId] = status;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    /**
     * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
     */
    function setTokenURI(uint256 tokenId, string memory _tokenURI)
        public
        onlyOwner
    {
        _tokenURIs[tokenId] = _tokenURI;
    }

    function setPuzzlePrice(uint256 puzzleId, uint256 price) public onlyOwner {
        puzzlePrice[puzzleId] = price;
    }

    function setMaxPiecesPerOwner(uint256 num) public onlyOwner {
        maxPiecesPerOwner = num;
    }

    // Private ---------------------------

    function removePuzzlePieceFromOwner(address owner, uint256 tokenId)
        private
    {
        _ownedPuzzlePieces[owner][pieceToPuzzle[tokenId]] -= 1;
    }

    function addPuzzlePieceToOwner(address owner, uint256 tokenId) private {
        _ownedPuzzlePieces[owner][pieceToPuzzle[tokenId]] += 1;
    }

    // Overrides ---------------------------

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        // If token is being transferred and not minted
        if (from != to && from != address(0)) {
            removePuzzlePieceFromOwner(from, tokenId);
        }

        // If token is being transferred and not burned
        if (to != from && to != address(0)) {
            addPuzzlePieceToOwner(to, tokenId);
        }
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`.
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev This is a variation of what is found in {ERC721URIStorage-tokenURI}.
     * We never concatenate the tokenURI with the baseURI.
     * If the tokenURI is set we just use that.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(_exists(tokenId), "URI query for nonexistent token");
        string memory _tokenURI = _tokenURIs[tokenId];

        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return _tokenURI;
        }

        return super.tokenURI(tokenId);
    }
}
