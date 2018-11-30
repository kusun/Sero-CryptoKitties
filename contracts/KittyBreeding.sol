pragma solidity ^0.4.25;
import "./KittyOwnership.sol";

/// @title A facet of KittyCore that manages Kitty siring, gestation, and birth.
/// @author Axiom Zen (https://www.axiomzen.co)
/// @dev See the KittyCore contract documentation to understand how the various contract facets are arranged.

contract KittyBreeding is KittyOwnership {

    /// @dev The Pregnant event is fired when two cats successfully breed and the pregnancy
    ///  timer begins for the matron.
    event Pregnant(bytes32 matronId, bytes32 sireId, uint256 cooldownEndBlock);

    /// @notice The minimum payment required to use breedWithAuto(). This fee goes towards
    ///  the gas cost paid by whatever calls giveBirth(), and can be dynamically updated by
    ///  the COO role as the gas price changes.
    uint256 public autoBirthFee = 2 finney;

    // Keeps track of number of pregnant kitties.
    uint256 public pregnantKitties;


    /// @dev Checks that a given kitten is able to breed. Requires that the
    ///  current cooldown is finished (for sires) and also checks that there is
    ///  no pending pregnancy.
    function _isReadyToBreed(KittyModel.Kitty _kit) internal view returns (bool) {
        // In addition to checking the cooldownEndBlock, we also need to check to see if
        // the cat has a pending birth; there can be some period of time between the end
        // of the pregnacy timer and the birth event.
        return (_kit.siringWithId == 0) && (_kit.cooldownEndBlock <= uint64(block.number));
    }

    /// @dev Check if a sire has authorized breeding with this matron. True if both sire
    ///  and matron have the same owner, or if the sire has given siring permission to
    ///  the matron (via approveSiring()).
    function _isSiringPermitted(bytes32 _sireId, bytes32 _matronId) internal view returns (bool) {
        // Siring is okay if they have same owner, or if the matron's owner was given
        // permission to breed with this sire.
        return ( kitties.get(_sireId).owner == kitties.get(_matronId).owner || sireAllowedToKittyId[_sireId] == _matronId);
    }

    /// @dev Set the cooldownEndTime for the given Kitty, based on its current cooldownIndex.
    ///  Also increments the cooldownIndex (unless it has hit the cap).
    /// @param _kitten A reference to the Kitty in storage which needs its timer started.
    function _triggerCooldown(KittyModel.Kitty storage _kitten) internal {
        // Compute an estimation of the cooldown time in blocks (based on current cooldownIndex).
        _kitten.cooldownEndBlock = uint64((cooldowns[_kitten.cooldownIndex]/secondsPerBlock) + block.number);

        // Increment the breeding count, clamping it at 13, which is the length of the
        // cooldowns array. We could check the array size dynamically, but hard-coding
        // this as a constant saves gas. Yay, Solidity!
        if (_kitten.cooldownIndex < 13) {
            _kitten.cooldownIndex += 1;
        }
    }

    /// @notice Grants approval to another kitty to sire with one of your Kitties.
    /// @param _matronId The kittyId that will be able to sire with your Kitty. Set to
    function approveSiring(bytes32 _matronId)
    external
    whenNotPaused
    {
        //get _sireId A Kitty that you own from the tx param
        bytes32 _sireId = sero_msg_ticket();
        sireAllowedToKittyId[_sireId] = _matronId;
        //Re-save _sireId to your personal account after approval
        sero_send_ticket(msg.sender,symbol,_sireId);
    }

    /// @dev Updates the minimum payment required for calling giveBirthAuto(). Can only
    ///  be called by the COO address. (This fee is used to offset the gas cost incurred
    ///  by the autobirth daemon).
    function setAutoBirthFee(uint256 val) external onlyCOO {
        autoBirthFee = val;
    }

    /// @dev Checks to see if a given Kitty is pregnant and (if so) if the gestation
    ///  period has passed.
    function _isReadyToGiveBirth(KittyModel.Kitty _matron) private view returns (bool) {
        return (_matron.siringWithId != 0) && (_matron.cooldownEndBlock <= uint64(block.number));
    }

    /// @notice Checks that a given kitten is able to breed (i.e. it is not pregnant or
    ///  in the middle of a siring cooldown).
    /// @param _kittyId reference the id of the kitten, any user can inquire about it
    function isReadyToBreed(bytes32 _kittyId)
    public
    view
    returns (bool)
    {
        require(_kittyId > 0);
        KittyModel.Kitty storage kit = kitties.get(_kittyId);
        return _isReadyToBreed(kit);
    }

    /// @dev Checks whether a kitty is currently pregnant.
    /// @param _kittyId reference the id of the kitten, any user can inquire about it
    function isPregnant(bytes32 _kittyId)
    public
    view
    returns (bool)
    {
        require(_kittyId > bytes32(0));
        // A kitty is pregnant if and only if this field is set
        return kitties.get(_kittyId).siringWithId != 0;
    }

    /// @dev Internal check to see if a given sire and matron are a valid mating pair. DOES NOT
    ///  check ownership permissions (that is up to the caller).
    /// @param _matron A reference to the Kitty struct of the potential matron.
    /// @param _matronId The matron's ID.
    /// @param _sire A reference to the Kitty struct of the potential sire.
    /// @param _sireId The sire's ID
    function _isValidMatingPair(
        KittyModel.Kitty storage _matron,
        bytes32 _matronId,
        KittyModel.Kitty storage _sire,
        bytes32 _sireId
    )
    private
    view
    returns(bool)
    {
        // A Kitty can't breed with itself!
        if (_matronId == _sireId) {
            return false;
        }

        // Kitties can't breed with their parents.
        if (_matron.matronId == _sireId || _matron.sireId == _sireId) {
            return false;
        }
        if (_sire.matronId == _matronId || _sire.sireId == _matronId) {
            return false;
        }

        // We can short circuit the sibling check (below) if either cat is
        // gen zero (has a matron ID of zero).
        if (_sire.matronId == 0 || _matron.matronId == 0) {
            return true;
        }

        // Kitties can't breed with full or half siblings.
        if (_sire.matronId == _matron.matronId || _sire.matronId == _matron.sireId) {
            return false;
        }
        if (_sire.sireId == _matron.matronId || _sire.sireId == _matron.sireId) {
            return false;
        }

        // Everything seems cool! Let's get DTF.
        return true;
    }

    /// @dev Internal check to see if a given sire and matron are a valid mating pair for
    ///  breeding via auction (i.e. skips ownership and siring approval checks).
    function _canBreedWithViaAuction(bytes32 _matronId, bytes32 _sireId)
    internal
    view
    returns (bool)
    {
        KittyModel.Kitty storage matron = kitties.get(_matronId);
        KittyModel.Kitty storage sire = kitties.get(_sireId);
        return _isValidMatingPair(matron, _matronId, sire, _sireId);
    }

    /// @notice Checks to see if two cats can breed together, including checks for
    ///  ownership and siring approvals. Does NOT check that both cats are ready for
    ///  breeding (i.e. breedWith could still fail until the cooldowns are finished).
    ///  TODO: Shouldn't this check pregnancy and cooldowns?!?
    /// @param _matronId The ID of the proposed matron.
    /// @param _sireId The ID of the proposed sire.
    function canBreedWith(bytes32 _matronId, bytes32 _sireId)
    external
    view
    returns(bool)
    {
        require(_matronId > 0);
        require(_sireId > 0);
        KittyModel.Kitty storage matron = kitties.get(_matronId);
        KittyModel.Kitty storage sire = kitties.get(_sireId);
        return _isValidMatingPair(matron, _matronId, sire, _sireId) &&
        _isSiringPermitted(_sireId, _matronId);
    }

    /// @dev Internal utility function to initiate breeding, assumes that all breeding
    ///  requirements have been checked.
    function _breedWith(bytes32 _matronId, bytes32 _sireId) internal {
        // Grab a reference to the Kitties from storage.
        KittyModel.Kitty storage sire = kitties.get(_sireId);
        KittyModel.Kitty storage matron = kitties.get(_matronId);

        // Mark the matron as pregnant, keeping track of who the sire is.
        matron.siringWithId = bytes32(_sireId);

        // Trigger the cooldown for both parents.
        _triggerCooldown(sire);
        _triggerCooldown(matron);

        // Clear siring permission for both parents. This may not be strictly necessary
        // but it's likely to avoid confusion!
        delete sireAllowedToKittyId[_matronId];
        delete sireAllowedToKittyId[_sireId];

        // Every time a kitty gets pregnant, counter is incremented.
        pregnantKitties++;

        // Emit the pregnancy event.
        Pregnant(_matronId, _sireId, matron.cooldownEndBlock);
    }

    /// @notice Breed a Kitty you own (as matron) with a sire that you own, or for which you
    ///  have previously been given Siring approval. Will either make your cat pregnant, or will
    ///  fail entirely. Requires a pre-payment of the fee given out to the first caller of giveBirth()
    /// @param _sireId The ID of the Kitty acting as sire (will begin its siring cooldown if successful)
    function breedWithAuto(bytes32 _sireId)
    external
    payable
    whenNotPaused
    {
        // Checks for payment.
        require(msg.value >= autoBirthFee);

        bytes32 _matronId = sero_msg_ticket();

        // Neither sire nor matron are allowed to be on auction during a normal
        // breeding operation, but we don't need to check that explicitly.
        // For matron: The caller of this function can't be the owner of the matron
        //   because the owner of a Kitty on auction is the auction house, and the
        //   auction house will never call breedWith().
        // For sire: Similarly, a sire on auction will be owned by the auction house
        //   and the act of transferring ownership will have cleared any oustanding
        //   siring approval.
        // Thus we don't need to spend gas explicitly checking to see if either cat
        // is on auction.

        // Check that matron and sire are both owned by caller, or that the sire
        // has given siring permission to caller (i.e. matron's owner).
        // Will fail for _sireId = 0
        require(_isSiringPermitted(_sireId, _matronId));

        // Grab a reference to the potential matron
        KittyModel.Kitty storage matron = kitties.get(_matronId);

        // Make sure matron isn't pregnant, or in the middle of a siring cooldown
        require(_isReadyToBreed(matron));

        // Grab a reference to the potential sire
        KittyModel.Kitty storage sire = kitties.get(_sireId);

        // Make sure sire isn't pregnant, or in the middle of a siring cooldown
        require(_isReadyToBreed(sire));

        // Test that these cats are a valid mating pair.
        require(_isValidMatingPair(
                matron,
                _matronId,
                sire,
                _sireId
            ));

        // All checks passed, kitty gets pregnant!
        _breedWith(_matronId, _sireId);

        sero_send_ticket(msg.sender,symbol,_matronId);
    }

    /// @notice Have a pregnant Kitty give birth!
    /// @param _matronId A Kitty ready to give birth.
    /// @return The Kitty ID of the new kitten.
    /// @dev Looks at a given Kitty and, if pregnant and if the gestation period has passed,
    ///  combines the genes of the two parents to create a new kitten. The new Kitty is assigned
    ///  to the current owner of the matron. Upon successful completion, both the matron and the
    ///  new kitten will be ready to breed again. Note that anyone can call this function (if they
    ///  are willing to pay the gas!), but the new kitten always goes to the mother's owner.
    function giveBirth(bytes32 _matronId)
    external
    whenNotPaused
    returns(bytes32)
    {
        // Grab a reference to the matron in storage.
        KittyModel.Kitty storage matron = kitties.get(_matronId);

        // Check that the matron is a valid cat.
        require(matron.birthTime != 0);

        // Check that the matron is pregnant, and that its time has come!
        require(_isReadyToGiveBirth(matron));

        // Grab a reference to the sire in storage.
        bytes32 sireId = matron.siringWithId;
        KittyModel.Kitty storage sire = kitties.get(sireId);

        // Determine the higher generation number of the two parents
        uint16 parentGen = matron.generation;
        if (sire.generation > matron.generation) {
            parentGen = sire.generation;
        }

        // Call the sooper-sekret gene mixing operation.
        uint256 childGenes = uint256(keccak256(block.difficulty,now));

        bytes32 kittenId = _createKitty(_matronId, matron.siringWithId, parentGen + 1, childGenes, matron.owner);

        // Clear the reference to sire from the matron (REQUIRED! Having siringWithId
        // set is what marks a matron as being pregnant.)
        delete matron.siringWithId;

        // Every time a kitty gives birth counter is decremented.
        pregnantKitties--;

        // Send the balance fee to the person who made birth happen.
        msg.sender.send(autoBirthFee);

        // return the new kitten's ID
        return kittenId;
    }
}
