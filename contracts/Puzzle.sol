// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Puzzle is ERC721, Ownable {
    // Counter for token IDs
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;
    string private _baseTokenURI;

    uint256 private _maxPiecesPerOwner = 3;

    string[] private _puzzleURIs; // Final puzzle URIs
    mapping(uint256 => bool) private _puzzleFinished;

    mapping(uint256 => uint256) private _totalPuzzlePieces; // Total puzzle pieces
    mapping(uint256 => uint256[]) private _puzzleToPiece; // Puzzle pieces minted
    mapping(uint256 => uint256) private _puzzlePrice; // Price of the puzzle pieces

    mapping(address => mapping(uint256 => uint256)) private _ownedPuzzlePieces; // How many pieces someone owns by puzzle
    mapping(uint256 => uint256) private _pieceToPuzzle; // Used to map tokens to puzzles

    // Events
    event NewPuzzlePieceFound(address sender, uint256 puzzle, uint256 tokenId);
    event PuzzleFinished(address sender, uint256 puzzleId);
    event NewPuzzleAdded(address sender, uint256 puzzleId);

    constructor(string memory baseURI) ERC721("Puzzle", "PIECE") {
        setBaseURI(baseURI);
    }

    // Minting
    function findPuzzlePieces(uint256 puzzleId, uint256 num) public {
        require(_puzzleFinished[puzzleId] != true, "Puzzle has been finished");
        require(puzzleId < _puzzleURIs.length, "Puzzle does not exist");
        require(
            _puzzleToPiece[puzzleId].length + num <=
                _totalPuzzlePieces[puzzleId],
            "This would exceed the total amount of pieces"
        );
        // require(msg.value >= _puzzlePrice[puzzle] * num, "Ether sent not correct");

        // Get how many pieces this address owns
        uint256 balance = _ownedPuzzlePieces[msg.sender][puzzleId];
        require(
            balance + num <= _maxPiecesPerOwner,
            "You cannot find more than 3 pieces"
        );

        // Get the current tokenId.
        uint256 newItemId = _tokenIds.current();

        for (uint256 i; i < num; i++) {
            uint256 tokenId = newItemId + i;

            // Map the token to puzzle and then mint
            _pieceToPuzzle[tokenId] = puzzleId;
            _puzzleToPiece[puzzleId].push(tokenId);
            _safeMint(msg.sender, tokenId);

            // Increment the counter for when the next NFT is minted.
            _tokenIds.increment();

            emit NewPuzzlePieceFound(msg.sender, puzzleId, tokenId);
        }
    }

    // Finishing/ burning
    function finishPuzzle(uint256 puzzleId) public {
        require(_puzzleFinished[puzzleId] != true, "Puzzle has been finished");
        uint256 balance = _ownedPuzzlePieces[msg.sender][puzzleId];
        require(
            balance == _totalPuzzlePieces[puzzleId],
            "You have not collected all the pieces"
        );

        // Burn all the puzzle pieces of the owner
        for (uint256 i; i < balance; i++) {
            uint256 tokenId = _puzzleToPiece[puzzleId][i];
            _burn(tokenId);
        }

        _puzzleFinished[puzzleId] = true;

        // Issue the final puzzle
        uint256 newItemId = _tokenIds.current();
        _safeMint(msg.sender, newItemId);
        _setTokenURI(newItemId, _puzzleURIs[puzzleId]);
        _tokenIds.increment();

        emit PuzzleFinished(msg.sender, puzzleId);
    }

    // Before token transfer hook
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

    function removePuzzlePieceFromOwner(address owner, uint256 tokenId)
        private
    {
        _ownedPuzzlePieces[owner][_pieceToPuzzle[tokenId]] -= 1;
    }

    function addPuzzlePieceToOwner(address owner, uint256 tokenId) private {
        _ownedPuzzlePieces[owner][_pieceToPuzzle[tokenId]] += 1;
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIds.current();
    }

    // Owner functions

    function addPuzzle(
        string memory puzzleURI,
        uint256 puzzlePieces,
        uint256 price
    ) public onlyOwner {
        // Add puzzle URI and get the id
        _puzzleURIs.push(puzzleURI);
        uint256 puzzleId = _puzzleURIs.length - 1;

        // Set the total puzzle pieces and price
        _totalPuzzlePieces[puzzleId] = puzzlePieces;
        _puzzlePrice[puzzleId] = price;

        emit NewPuzzleAdded(msg.sender, puzzleId);
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    /**
     * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI)
        public
        onlyOwner
    {
        _tokenURIs[tokenId] = _tokenURI;
    }

    // Overridden functions

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

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`.
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }
}
