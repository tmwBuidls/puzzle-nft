// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Puzzle is ERC721Enumerable, Ownable {
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

    constructor() ERC721("Puzzle", "PIECE") {}

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

        // Get the total pieces to use as token id
        uint256 totalSupply = totalSupply();

        for (uint256 i; i < num; i++) {
            uint256 tokenId = totalSupply + i;

            // Map the token to puzzle and then mint
            _pieceToPuzzle[tokenId] = puzzleId;
            _puzzleToPiece[puzzleId].push(tokenId);
            _safeMint(msg.sender, tokenId);

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
        // TODO - set the token uri.
        _safeMint(msg.sender, totalSupply());

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

    // Owner commands

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
}
