// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {ERC721AMock} from "../Contracts/mocks/ERC721AMock.sol";
import {ERC721A__IERC721Receiver} from "../Contracts/ERC721A.sol";

contract ERC721ARecipient is ERC721A__IERC721Receiver {
    address public operator;
    address public from;
    uint256 public id;
    bytes public data;

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _id,
        bytes calldata _data
    ) public virtual override returns (bytes4) {
        operator = _operator;
        from = _from;
        id = _id;
        data = _data;

        return ERC721A__IERC721Receiver.onERC721Received.selector;
    }
}

contract RevertingERC721Recipient is ERC721A__IERC721Receiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public virtual override returns (bytes4) {
        revert(string(abi.encodePacked(ERC721A__IERC721Receiver.onERC721Received.selector)));
    }
}

contract WrongReturnDataERC721Recipient is ERC721A__IERC721Receiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public virtual override returns (bytes4) {
        return 0xCAFEBEEF;
    }
}

contract NonERC721Recipient {}

contract ERC721ATest is Test {
    ERC721AMock erc721a;
    address minter = vm.addr(1);
    address alice = vm.addr(2);

    function setUp() public {
        erc721a = new ERC721AMock("Azuki","AZUKI");
    }

    //Check the NFT Name 
    function testName() public {
        assertEq("Azuki",erc721a.name());
    }
    
    //check the NFT Symbol
    function testSymol() public {
        assertEq("AZUKI",erc721a.symbol());
    }

    function testERC165Support() view public {
        // support the IERC721
        assert(erc721a.supportsInterface(bytes4(0x80ac58cd)));
        // support the ERC721Metadata
        assert(erc721a.supportsInterface(bytes4(0x5b5e139f)));
    }

    function testMint() public {
        assertEq(erc721a.totalSupply(), 0);
        erc721a.mint(minter, 2);    // mint 2 NFTs
        erc721a.mint(alice, 5);    // mint 5 NFTs
        assertEq(erc721a.totalSupply(), 7);      
        assertEq(erc721a.balanceOf(minter),2);  // check the balance of minter  
        assertEq(erc721a.balanceOf(alice),5);  // check the balance of alice
    }

    function testBurn() public {
        erc721a.mint(minter, 1);    // mint 5 NFTs
        erc721a.burn(0, false);
        assertEq(erc721a.balanceOf(minter), 0);
    }

    function testApprove() public {
        erc721a.mint(address(this), 1);    // mint 1 NFT
        erc721a.approve(alice,0);
        assertEq(erc721a.getApproved(0),alice);
    }

    function testApproveBurn() public {
        erc721a.mint(address(this), 1);    // mint 1 NFT
        erc721a.approve(alice,0);
        vm.prank(alice);
        erc721a.burn(0, true);
        assertEq(erc721a.totalSupply(), 0);
    }

    function testApproveAll() public {
        erc721a.setApprovalForAll(alice, true); // set alice to approve all NFTs
        assert(erc721a.isApprovedForAll(address(this), alice));
    }

    function testTransferFrom() public {
        erc721a.mint(address(this), 1);    // mint 1 NFT
        erc721a.approve(alice,0);
        vm.startPrank(alice);
        erc721a.transferFrom(address(this), alice, 0);
        assertEq(erc721a.balanceOf(address(this)), 0);
        assertEq(erc721a.balanceOf(alice), 1);
    }

    function testTransferFromSelf() public {
        erc721a.mint(address(this), 1);    // mint 1 NFT
        erc721a.transferFrom(address(this), alice, 0);
        assertEq(erc721a.getApproved(0), address(0));  // check the approved address
        assertEq(erc721a.ownerOf(0), alice);  // check the owner
        assertEq(erc721a.balanceOf(address(this)), 0);
        assertEq(erc721a.balanceOf(alice), 1);
    }

    function testTransferFromApproveAll() public {
        erc721a.mint(alice, 1);    // mint 1 NFT
        vm.prank(alice);
        erc721a.setApprovalForAll(address(this), true);

        erc721a.transferFrom(alice, address(this), 0);
        assertEq(erc721a.getApproved(0), address(0));  // check the approved address
        assertEq(erc721a.balanceOf(address(this)), 1);
        assertEq(erc721a.balanceOf(alice), 0);
    }

    function testSafeTransferFromToEOA() public {
        erc721a.mint(minter, 1);    // mint 1 NFT
        vm.prank(minter);
        erc721a.setApprovalForAll(address(this), true);
        erc721a.safeTransferFrom(minter, alice , 0);
        assertEq(erc721a.getApproved(0),address(0));
        assertEq(erc721a.ownerOf(0), alice);
        assertEq(erc721a.balanceOf(minter), 0);
        assertEq(erc721a.balanceOf(alice), 1);
    }

    function testSafeTransferFromToERC721Recipient() public {
        erc721a.mint(minter, 1);    // mint 1 NFT
        vm.prank(minter);
        erc721a.setApprovalForAll(address(this), true);
        ERC721ARecipient recipient = new ERC721ARecipient();
        erc721a.safeTransferFrom(minter, address(recipient), 0);
        assertEq(erc721a.getApproved(0),address(0));
        assertEq(erc721a.ownerOf(0), address(recipient));
   
        assertEq(recipient.operator(), address(this));
        assertEq(recipient.from(), minter);
        assertEq(recipient.id(), 0);
        assertEq(recipient.data(), "");
    }
    
    function testSafeTransferFromToERC721RecipientWithData() public { 
        erc721a.mint(minter, 1);    // mint 1 NFT
        vm.prank(minter);
        erc721a.setApprovalForAll(address(this), true);
        ERC721ARecipient recipient = new ERC721ARecipient();
        erc721a.safeTransferFrom(minter, address(recipient), 0 , "Transfer 0 NFTs");
        assertEq(erc721a.getApproved(0),address(0));
        assertEq(erc721a.ownerOf(0), address(recipient));
   
        assertEq(recipient.operator(), address(this));
        assertEq(recipient.from(), minter);
        assertEq(recipient.id(), 0);
        assertEq(recipient.data(), "Transfer 0 NFTs");
    }

    

    function testSafeMintWithData() public {
        assertEq(erc721a.totalSupply(), 0);
        erc721a.safeMint(minter, 2, "Hello"); // mint 2 NFTs with data
        assertEq(erc721a.totalSupply(), 2);
        assertEq(erc721a.balanceOf(minter),2);  // check the balance of minter
    }

    function testSafeMintWithDataAndReceiver() public {
        ERC721ARecipient to = new ERC721ARecipient();
        assertEq(erc721a.totalSupply(), 0);
        erc721a.safeMint(address(to), 2, "Hello"); // mint 2 NFTs with data and receiver
        assertEq(erc721a.totalSupply(), 2);
    }

    function testNumberMinted() public { 
        assertEq(erc721a.numberMinted(minter), 0);
        erc721a.safeMint(minter, 2);    // mint 2 NFTs
        assertEq(erc721a.numberMinted(minter),2);  // check the number of NFTs minted by minter
        erc721a.safeMint(alice, 10);     // mint 10 NFTs
        assertEq(erc721a.numberMinted(alice),10);  // check the number of NFTs minted by alice
    }

    function testNumberMintedWithData() public { 
        assertEq(erc721a.numberMinted(minter), 0);
        erc721a.safeMint(minter, 2, "Hello"); // mint 2 NFTs with data
        assertEq(erc721a.numberMinted(minter),2);  // check the number of NFTs minted by minter
    }

    function testNumberMintedWithDataAndReceiver() public { 
        ERC721ARecipient to = new ERC721ARecipient();
        assertEq(erc721a.numberMinted(address(to)), 0);
        erc721a.safeMint(address(to), 2, "Hello"); // mint 2 NFTs with data and receiver
        assertEq(erc721a.numberMinted(address(to)),2);  // check the number of NFTs minted by minter
    }

    function testBurnWithNonApprovalCheck() public {
        erc721a.mint(minter, 2);    // mint 2 NFTs
        assertEq(erc721a.balanceOf(minter),2);   // check the balance of minter
        erc721a.burn(1, false);    // burn 1 NFT
        assertEq(erc721a.balanceOf(minter),1);   // check the balance of minter
    }

    function testBurnWithApprovalCheck() public {
        vm.startPrank(minter);
        erc721a.mint(minter, 2);    // mint 2 NFTs
        assertEq(erc721a.balanceOf(minter),2);   // check the balance of minter
        erc721a.burn(0, true);    // burn 1 NFT
        assertEq(erc721a.balanceOf(minter),1);   // check the balance of minter
    }

    function testBurnWithNonEOAAccountAndWithApprovalCheck() public {
        vm.startPrank(minter);
        erc721a.mint(minter, 2);    // mint 2 NFTs
        erc721a.setApprovalForAll(address(this), true);
        vm.stopPrank();
        vm.prank(address(this));
        erc721a.burn(1, true);    // burn 1 NFT
    }

    function testFailERC165Support() public {
        // does not support ERC721Enumerable
        assertEq(erc721a.supportsInterface(bytes4(0x780e9d63)), true);
        // does not support random bytes4 value
        assertEq(erc721a.supportsInterface(bytes4(0x00004548)), true);
    }

    function testFailSafeMintToNonERC721Recipient() public {
         NonERC721Recipient to = new NonERC721Recipient();
        erc721a.safeMint(address(to), 2); // mint 2 NFTs to 
    }

    function testFailSafeMintWithDataAndReceiverAndNonERC721Recipient() public {
        NonERC721Recipient to = new NonERC721Recipient();
        erc721a.safeMint(address(to), 2, "Hello"); // mint 2 NFTs to with data and receiver
    }

    function testFailSafeMintToERC721RecipientWithWrongReturnData() public {
       WrongReturnDataERC721Recipient to = new WrongReturnDataERC721Recipient();
       erc721a.safeMint(address(to), 2); // mint 2 NFTs to with data and receiver
    }

    function testFailSafeMintWithDataAndReceiverAndWrongReturnData() public {
        WrongReturnDataERC721Recipient to = new WrongReturnDataERC721Recipient();
        erc721a.safeMint(address(to), 2, "Hello"); // mint 2 NFTs with data and receiver 
    }

    function testFailSafeMintToRevertingERC721Recipient() public {
        RevertingERC721Recipient to = new RevertingERC721Recipient();
        erc721a.safeMint(address(to), 2); // mint 2 NFTs to with data and receiver
    }

    function testFailSafeMintWithDataAndReceiverAndRevertingERC721Recipient() public {
        RevertingERC721Recipient to = new RevertingERC721Recipient();
        erc721a.safeMint(address(to), 2, "Hello"); // mint 2 NFTs with data and receiver
    }

    function testFailBurnUnMinted() public {
        erc721a.burn(1, false);
    }

    function testFailDoubleBurn() public {
        vm.startPrank(minter);
        erc721a.mint(minter, 1);    // mint 1 NFTs
        erc721a.burn(0 , false);    // burn 1 NFT
        erc721a.burn(0 , false);    // duplicate burn
    }

    function testFailBurnWithNonEOAAccountAndWithApprovalCheck() public {
        erc721a.mint(minter, 1);    // mint 1 NFTs
        erc721a.burn(0 , true);    // burn 1 NFT
    }

    function testFailBurnWithApprovalCheckAndWithEOAAccount() public {
        vm.prank(minter);
        erc721a.mint(minter, 1);    // mint 1 NFTs
        vm.prank(alice);
        erc721a.burn(0 , true);    // burn 1 NFT
    }

    function testFailBalanceOfZeroAddress() public view {
        erc721a.balanceOf(address(0));
    }

    function testFailOwnerOfUnminted() public view {
        erc721a.ownerOf(1337);
    }

}

