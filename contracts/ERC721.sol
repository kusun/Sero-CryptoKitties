/// @title Interface for contracts conforming to ERC-721: Non-Fungible Tokens
/// @author Dieter Shirley <dete@axiomzen.co> (https://github.com/dete)

contract ERC721 {

    function totalSupply() public view returns (uint256 total);

    function transfer(address _to, bytes32 _tokenId) external;

    // Events
    event Transfer(address from, address to, uint256 tokenId);
}
