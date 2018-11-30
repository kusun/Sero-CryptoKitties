pragma solidity ^0.4.25;
import "./../seroInterface.sol";
import "./KittyAccessControl.sol";
import "./SaleClockAuction.sol";
import "./SiringClockAuction.sol";


library KittyModel {
    struct Kitty {
        bytes32 kittyId;
        uint256 genes;
        uint64 birthTime;
        uint64 cooldownEndBlock;
        bytes32 matronId;
        bytes32 sireId;
        bytes32 siringWithId;
        uint16 cooldownIndex;
        uint16 generation;
        address owner;
    }

    struct List {
        mapping(bytes32 => Kitty) kittys;
        uint256 len;
    }

    function push(List storage self, Kitty kitty) internal {
        self.kittys[kitty.kittyId] = kitty;
        self.len++;
    }

    function get(List storage self, bytes32 kittyId) internal view returns(Kitty storage) {
        return self.kittys[kittyId];
    }
}

contract KittyBase is KittyAccessControl ,SeroInterface{

    string public constant name = "CryptoKitties";
    string public constant symbol = "CK";

    /// @dev The Birth event is fired whenever a new kitten comes into existence. This obviously
    ///  includes any time a cat is created through the giveBirth method, but it is also called
    ///  when a new gen0 cat is created.
    event Birth(address owner, bytes32 kittyId, bytes32 matronId, bytes32 sireId, uint256 genes);

    /// @dev Transfer event as defined in current draft of ERC721. Emitted every time a kitten
    ///  ownership is assigned, including births.
    event Transfer(address from, address to, bytes32 tokenId);


    /*** CONSTANTS ***/

    /// @dev A lookup table indicating the cooldown duration after any successful
    ///  breeding action, called "pregnancy time" for matrons and "siring cooldown"
    ///  for sires. Designed such that the cooldown roughly doubles each time a cat
    ///  is bred, encouraging owners not to just keep breeding the same cat over
    ///  and over again. Caps out at one week (a cat can breed an unbounded number
    ///  of times, and the maximum cooldown is always seven days).
    uint32[14] public cooldowns = [
    uint32(1 minutes),
    uint32(2 minutes),
    uint32(5 minutes),
    uint32(10 minutes),
    uint32(30 minutes),
    uint32(1 hours),
    uint32(2 hours),
    uint32(4 hours),
    uint32(8 hours),
    uint32(16 hours),
    uint32(1 days),
    uint32(2 days),
    uint32(4 days),
    uint32(7 days)
    ];

    // An approximation of currently how many seconds are in between blocks.
    uint256 public secondsPerBlock = 15;

    using KittyModel for KittyModel.List;

    KittyModel.List kitties;

    /// @dev A mapping from KittyIDs to an address that has been approved to use
    ///  this Kitty for siring via breedWith(). Each Kitty can only have one approved
    ///  address for siring at any time. A zero value means no approval is outstanding.
    mapping (bytes32 => bytes32) public sireAllowedToKittyId;

    /// @dev The address of the ClockAuction contract that handles sales of Kitties. This
    ///  same contract handles both peer-to-peer sales as well as the gen0 sales which are
    ///  initiated every 15 minutes.
    SaleClockAuction public saleAuction;

    /// @dev The address of a custom ClockAuction subclassed contract that handles siring
    ///  auctions. Needs to be separate from saleAuction because the actions taken on success
    ///  after a sales and siring auction are quite different.
    SiringClockAuction public siringAuction;

    /// @dev An internal method that creates a new kitty and stores it to the owner account. This
    ///  method doesn't do any checking and should only be called when the
    ///  input data is known to be valid. Will generate both a Birth event
    ///  and a Transfer event.
    /// @param _matronId The kitty ID of the matron of this cat (zero for gen0)
    /// @param _sireId The kitty ID of the sire of this cat (zero for gen0)
    /// @param _generation The generation number of this cat, must be computed by caller.
    /// @param _genes The kitty's genetic code.
    /// @param _owner The inital owner of this cat, must be non-zero (except for the unKitty, ID 0)
    function _createKitty(
        bytes32 _matronId,
        bytes32 _sireId,
        uint256 _generation,
        uint256 _genes,
        address _owner
    )
    internal
    returns (bytes32)
    {
        require(_generation == uint256(uint16(_generation)));

        // New kitty starts with the same cooldown as parent gen/2
        uint16 cooldownIndex = uint16(_generation / 2);
        if (cooldownIndex > 13) {
            cooldownIndex = 13;
        }
        //creates a new kitty and stores it to the owner account
        bytes32 newKittenId = sero_allotTicket(_owner, 0, symbol);

        // emit the Transfer event
        Transfer(0, _owner, newKittenId);

        require(newKittenId != 0);
        KittyModel.Kitty memory _kitty = KittyModel.Kitty({
            kittyId: newKittenId,
            genes: _genes,
            birthTime: uint64(now),
            cooldownEndBlock: 0,
            matronId: _matronId,
            sireId: _sireId,
            siringWithId: 0,
            cooldownIndex: cooldownIndex,
            generation: uint16(_generation),
            owner: _owner
            });
        kitties.push(_kitty);

        // emit the birth event
        Birth(
            _owner,
            newKittenId,
            _kitty.matronId,
            _kitty.sireId,
            _kitty.genes
        );

        return newKittenId;
    }

    // Any C-level can fix how many seconds per blocks are currently observed.
    function setSecondsPerBlock(uint256 secs) external onlyCLevel {
        require(secs < cooldowns[0]);
        secondsPerBlock = secs;
    }

    function stringToBytes(string memory source) internal pure returns  (bytes32 result) {
        assembly {
            result := mload(add(source, 32))
        }
    }

    function stringEq(string a, string b) internal pure returns (bool) {
        if (bytes(a).length != bytes(b).length) {
            return false;
        } else {
            return stringToBytes(a) == stringToBytes(b);
        }
    }
}
