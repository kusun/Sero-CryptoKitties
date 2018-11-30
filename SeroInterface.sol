

pragma solidity ^0.4.25;

contract SeroInterface {

    /**
     * the follow topics is system topics,can not be changed at will
     */
    bytes32 private topic_sero_issueToken     =  0x3be6bf24d822bcd6f6348f6f5a5c2d3108f04991ee63e80cde49a8c4746a0ef3;
    bytes32 private topic_sero_balanceOf      =  0xcf19eb4256453a4e30b6a06d651f1970c223fb6bd1826a28ed861f0e602db9b8;
    bytes32 private topic_sero_send           =  0x868bd6629e7c2e3d2ccf7b9968fad79b448e7a2bfb3ee20ed1acbc695c3c8b23;
    bytes32 private topic_sero_currency       =  0x7c98e64bd943448b4e24ef8c2cdec7b8b1275970cfe10daf2a9bfa4b04dce905;
    bytes32 private topic_sero_setCurrency    =  0x0d3419022a97c2b5b03008b32a2cb33ab9f9b6721ce570c5031e04b6eadeb630;
    bytes32 private topic_sero_allotTicket    =  0xa6a366f1a72e1aef5d8d52ee240a476f619d15be7bc62d3df37496025b83459f;
    bytes32 private topic_sero_category       =  0xf1964f6690a0536daa42e5c575091297d2479edcc96f721ad85b95358644d276;
    bytes32 private topic_sero_ticket         =  0x9ab0d7c07029f006485cf3468ce7811aa8743b5a108599f6bec9367c50ac6aad;

    /**
    * @dev convert bytes 32 to string
    * @param  x the string btyes32
    */
    function bytes32ToString(bytes32 x) public pure returns (string) {
        bytes memory bytesString = new bytes(32);
        uint charCount = 0;
        for (uint j = 0; j < 32; j++) {
            byte char = byte(bytes32(uint(x) * 2 ** (8 * j)));
            if (char != 0) {
                bytesString[charCount] = char;
                charCount++;
            } else {
                break;
            }
        }
        bytes memory bytesStringTrimmed = new bytes(charCount);
        for (j = 0; j < charCount; j++) {
            bytesStringTrimmed[j] = bytesString[j];
        }
        return string(bytesStringTrimmed);
    }

    /**
    * @dev set the token currency
    * @param _currency the crurrency of the token
    */
    function sero_setCurrency(string _currency) internal {
        assembly {
            log1(_currency, 0x40, sload(topic_sero_setCurrency_slot))
        }
        return;
    }

    /**
    * @dev the get currency from the tx params
    */
    function sero_msg_currency() internal returns (string) {
        bytes memory tmp = new bytes(32);
        bytes32 b32;
        assembly {
            log1(tmp, 0x20, sload(topic_sero_currency_slot))
            b32 := mload(tmp)
        }
        return bytes32ToString(b32);
    }

    /**
    * @dev issue the token
    * @param _total the totalsupply of the token
    * @param _currency the currency ot the token
    */
    function sero_issueToken(uint256 _total,string memory _currency) internal returns (bool success){
        bytes memory temp = new bytes(64);
        assembly {
            mstore(temp, _currency)
            mstore(add(temp, 0x20), _total)
            log1(temp, 0x40, sload(topic_sero_issueToken_slot))
            success := mload(add(temp, 0x20))
        }
        return;
    }

    /**
     * @dev the balance of this contract
     * @param _currency the currency ot the token
     */
    function sero_balanceOf(string memory _currency) internal returns (uint256 amount){
        bytes memory temp = new bytes(32);
        assembly {
            mstore(temp, _currency)
            log1(temp, 0x20, sload(topic_sero_balanceOf_slot))
            amount := mload(temp)
        }
        return;
    }

    /**
     * @dev transfer the token to the receiver
     * @param _receiver the address of receiver
     * @param _currency the currency of token
     * @param _amount the amount of token
     */
    function sero_send_token(address _receiver, string memory _currency, uint256 _amount)internal returns (bool success){
        return sero_send(_receiver,_currency,_amount,"",0);
    }

    /**
     * @dev transfer the token or ticket to the receiver
     * @param _receiver the address of receiver
     * @param _currency the currency of token
     * @param _amount the amount of token
     * @param _category the category of the ticket
     * @param _ticket the Id of the ticket
     */
    function sero_send(address _receiver, string memory _currency, uint256 _amount, string memory _category, bytes32 _ticket)internal returns (bool success){
        bytes memory temp = new bytes(160);
        assembly {
            mstore(temp, _receiver)
            mstore(add(temp, 0x20), _currency)
            mstore(add(temp, 0x40), _amount)
            mstore(add(temp, 0x60), _category)
            mstore(add(temp, 0x80), _ticket)
            log1(temp, 0xa0, sload(topic_sero_send_slot))
            success := mload(add(temp, 0x80))
        }
        return;
    }

    /**
     * @dev the get category from the tx params
     */
    function sero_msg_category() internal returns (string) {
        bytes memory tmp = new bytes(32);
        bytes32 b32;
        assembly {
            log1(tmp, 0x20, sload(topic_sero_category_slot))
            b32 := mload(tmp)
        }
        return bytes32ToString(b32);
    }

    /**
    * @dev the get ticketId from the tx params
    */
    function sero_msg_ticket() internal returns (bytes32 value) {
        bytes memory tmp = new bytes(32);
        assembly {
            log1(tmp, 0x20, sload(topic_sero_ticket_slot))
            value := mload(tmp)
        }
        return;
    }

    /**
     * @dev generate a tickeId and allot to the receiver address
     * @param _receiver receiving address of tickeId
     * @param _value  the seq of tickeId,can be zero. if zero the system ，the system randomly generates
     * @param _category the category of the ticket
     */
    function sero_allotTicket(address _receiver, bytes32 _value, string memory _category) internal returns (bytes32 ticket){
        bytes memory temp = new bytes(96);
        assembly {
            let start := temp
            mstore(start, _value)
            mstore(add(start, 0x20), _receiver)
            mstore(add(start, 0x40), _category)
            log1(start, 0x60, sload(topic_sero_allotTicket_slot))
            ticket := mload(add(start, 0x40))
        }
        return;
    }


    /**
   * @dev transfer the tickeId to the receiver
   * @param _receiver the address of receiver
   * @param _category the category of ticket
   * @param _ticket the tickeId
   */
    function sero_send_ticket(address _receiver, string memory _category, bytes32 _ticket)internal returns (bool success){
        return sero_send(_receiver,"",0,_category,_ticket);
    }
}

