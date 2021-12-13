const { expect, assert } = require('chai');
const truffleAssert = require('truffle-assertions');
const { ethers } = require('ethers');
// Load compiled artifacts
const PuggNFT = artifacts.require("PuggNFT");
const TESTToken = artifacts.require("TESTToken");
const TESTToken_6 = artifacts.require("TESTToken_6");
const PuggPool = artifacts.require("PuggPool");
const PuggNFTSale = artifacts.require("PuggNFTSale");

const delay = ms => new Promise(resolve => setTimeout(resolve, ms))
// Start test block
contract('PuggNFT_Swap Test', function (accounts) {
    describe('check for PuggNFT_Swap',() => {
        let pugg_nft;
        let pugg_pool;
        let points_token;
        let base_token;
        let pugg_swap;
        let frist_token_Id;
        let dec_base;
        let dec_points;

        const owner = accounts[0];
        const node1 = accounts[1];
        const transferTo = accounts[2];
        const executor = accounts[3];
        const node2 = accounts[4];
        const node3 = accounts[5];
        const project = accounts[6];
        const address_0 = "0x0000000000000000000000000000000000000000000000000000000000000000";
        
        beforeEach(async function () {
            points_token = await TESTToken.new();
            base_token = await TESTToken_6.new();
            pugg_nft = await PuggNFT.new();
            await pugg_nft.__PuggNFT_init("puggnft", "PUGNFT", "https://ipfs.rarible.com", "https://ipfs.rarible.com");
            pugg_pool = await PuggPool.new();
            await pugg_pool.__initialize(pugg_nft.address, points_token.address, 0, 9995, 0);
            pugg_swap = await PuggNFTSale.new();
            await pugg_swap.__initialize(pugg_nft.address, base_token.address, points_token.address, pugg_pool.address, project);
            let balance = await points_token.balanceOf(owner);
            await points_token.transfer(pugg_swap.address, balance);
            await pugg_nft.setDefaultApproval(pugg_swap.address, true);

            // add card
            dec_base = await base_token.decimals();
            dec_points = await points_token.decimals();
            card_fee = ethers.utils.parseUnits("10", dec_base);
            card_points = ethers.utils.parseUnits("10000", dec_points);
            await pugg_swap.addCard(1, card_fee, card_points, "tokenURI");

            frist_token_Id = web3.utils.toBN(pugg_swap.address + "000000000000000000000000");
        });

        it("check for init params", async () => {
            assert.equal(await pugg_nft.name(), "puggnft");
            assert.equal(await pugg_nft.symbol(), "PUGNFT");
            assert.equal(await pugg_nft.isApprovedForAll(owner, pugg_swap.address), true);
            assert.equal(await pugg_swap.pugg_ntf(), pugg_nft.address);
            assert.equal(await pugg_swap.base_token(), base_token.address);
            assert.equal(await pugg_swap.points_token(), points_token.address);
            let token_Id = await pugg_swap.cur_token_Id();
            assert.equal(token_Id.toString(), web3.utils.toBN(pugg_swap.address + "000000000000000000000000").toString());
        });

        it("check for card", async () => {
            assert.equal((await pugg_swap.getCardCount()).toString(), "1");
            var card = await pugg_swap.cards(1);
            assert.equal(card.fee.toString(), card_fee.toString());
            assert.equal(card.points.toString(), card_points.toString());
            assert.equal(card.tokenURI, "tokenURI");
            assert.equal(card.active, true);
            
            await pugg_swap.setCard(1, 1, 1, "tokenURI2");
            var card = await pugg_swap.cards(1);
            assert.equal(card.fee.toString(), "1");
            assert.equal(card.points.toString(), "1");
            assert.equal(card.tokenURI, "tokenURI2");
            assert.equal(card.active, true);

            await pugg_swap.delCard(1, false);
            var card = await pugg_swap.cards(1);
            assert.equal(card.active, false);
        })

        it("check for createNode", async () => {
            await truffleAssert.reverts(pugg_swap.createNode(["ch01","ch02"], [node1,node2,node3]),
            "array length is different");
            await truffleAssert.reverts(pugg_swap.createNode(["ch01","ch02", "ch01"], [node1,node2,node3]),
            "code is already exists");
            await pugg_swap.createNode(["ch01"],[node1]);
            let codes = await pugg_swap.getNodeCodes();
            assert.equal(codes.length, 1);
            assert.equal(codes[0], "ch01");

            await truffleAssert.reverts(pugg_swap.getNodeInfo("ch01",{from:node2}),
            "Ownable: caller is neither node nor owner");

            let node = await pugg_swap.getNodeInfo("ch01",{from:node1});
            assert.equal(node.account, node1);
            assert.equal(node.state, 1);
        })

        it("check for mintAndTransfer_721", async () => {
            await pugg_swap.createNode(["ch01"],[node1]);
            await truffleAssert.reverts(pugg_swap.setPercent_n(100), // 1%
            "caller is not executor");
            await truffleAssert.reverts(pugg_swap.setPercent_m(100), // 1%
            "caller is not executor");
            await truffleAssert.reverts(pugg_swap.setPercent_x(100), // 1%
            "caller is not executor");
            await truffleAssert.reverts(pugg_swap.setPercent_y(100), // 1%
            "caller is not executor");
            await pugg_swap.setExecutor(executor);

            await pugg_swap.setPercent_n(100, {from:executor}) // 1%
            await pugg_swap.setPercent_m(200, {from:executor}) // 2%
            await pugg_swap.setPercent_x(400, {from:executor}) // 4%
            await pugg_swap.setPercent_y(1000, {from:executor}) // 10%

            await truffleAssert.reverts(pugg_swap.mintAndTransfer_721(2, "ch01", transferTo),
            "card id does not exist or not activated");
            await truffleAssert.reverts(pugg_swap.mintAndTransfer_721(1, "ch02", transferTo),
            "code is not exists");
            await truffleAssert.reverts(pugg_swap.mintAndTransfer_721(1, "ch01", transferTo),
            "fee allowance is not enough");

            var project_balance_0 = await pugg_swap.project_balance();
            var project_points_0 = await pugg_swap.project_points();
            assert.equal(project_balance_0.toString(), "0");
            assert.equal(project_points_0.toString(), "0");

            var node = await pugg_swap.getNodeInfo("ch01");
            assert.equal(node.balance.toString(), "0");
            assert.equal(node.points.toString(), "0");

            await base_token.approve(pugg_swap.address, card_fee);
            await pugg_swap.mintAndTransfer_721(1, "ch01", transferTo);
            var balance = await pugg_nft.balanceOf(transferTo);
            assert.equal(balance, 1);
            var _address = await pugg_nft.ownerOf(frist_token_Id);
            assert.equal(_address, transferTo);

            var project_balance = await pugg_swap.project_balance();
            var project_points = await pugg_swap.project_points();
            
            assert.equal(project_balance.toString(), ethers.utils.parseUnits("5", dec_base).toString());//50%
            assert.equal(project_points.toString(), ethers.utils.parseUnits("100", dec_points).toString()); // n%

            var node = await pugg_swap.getNodeInfo("ch01");
            assert.equal(node.balance.toString(), ethers.utils.parseUnits("5", dec_base).toString());//50%
            assert.equal(node.points.toString(), ethers.utils.parseUnits("1000", dec_points).toString()); // y%

            assert.equal((await base_token.balanceOf(pugg_swap.address)).toString(), card_fee.toString());
        });

        it("check for withdraw_n", async () => {
            await pugg_swap.createNode(["ch01"],[node1]);
            await pugg_swap.setExecutor(executor);
            await pugg_swap.setPercent_n(100, {from:executor}) // 1%
            await pugg_swap.setPercent_m(200, {from:executor}) // 2%
            await pugg_swap.setPercent_x(400, {from:executor}) // 4%
            await pugg_swap.setPercent_y(1000, {from:executor}) // 10%

            await base_token.approve(pugg_swap.address, card_fee);
            await pugg_swap.mintAndTransfer_721(1, "ch01", transferTo);

            var node = await pugg_swap.getNodeInfo("ch01");
            assert.equal(node.balance.toString(), ethers.utils.parseUnits("5", dec_base).toString());//50%
            assert.equal(node.points.toString(), ethers.utils.parseUnits("1000", dec_points).toString()); // y%

            await truffleAssert.reverts(pugg_swap.withdraw_n("ch01", 3, {from:node2}),
            "Ownable: caller is not node");
            await truffleAssert.reverts(pugg_swap.withdraw_n("ch01", 3, {from:node1}),
            "type is error");

            await pugg_swap.withdraw_n("ch01", 0, {from:node1});
            var node = await pugg_swap.getNodeInfo("ch01");
            assert.equal(node.balance.toString(), ethers.utils.parseUnits("0", dec_base).toString());//50%
            assert.equal(node.points.toString(), ethers.utils.parseUnits("1000", dec_points).toString()); //y%
            assert.equal((await base_token.balanceOf(node1)).toString(), ethers.utils.parseUnits("5", dec_base).toString());

            await pugg_swap.withdraw_n("ch01", 1, {from:node1});
            var node = await pugg_swap.getNodeInfo("ch01");
            assert.equal(node.balance.toString(), ethers.utils.parseUnits("0", dec_base).toString());//50%
            assert.equal(node.points.toString(), ethers.utils.parseUnits("0", dec_points).toString()); //y%
            assert.equal((await base_token.balanceOf(node1)).toString(), ethers.utils.parseUnits("5", dec_base).toString());
            assert.equal((await points_token.balanceOf(node1)).toString(), ethers.utils.parseUnits("1000", dec_points).toString());
        });

        it("check for withdraw_p", async () => {
            await pugg_swap.createNode(["ch01"],[node1]);
            await pugg_swap.setExecutor(executor);
            await pugg_swap.setPercent_n(100, {from:executor}) // 1%
            await pugg_swap.setPercent_m(200, {from:executor}) // 2%
            await pugg_swap.setPercent_x(400, {from:executor}) // 4%
            await pugg_swap.setPercent_y(1000, {from:executor}) // 10%

            await base_token.approve(pugg_swap.address, card_fee);
            await pugg_swap.mintAndTransfer_721(1, "ch01", transferTo);

            var project_balance = await pugg_swap.project_balance();
            var project_points = await pugg_swap.project_points();
            
            assert.equal(project_balance.toString(), ethers.utils.parseUnits("5", dec_base).toString());    //50%
            assert.equal(project_points.toString(), ethers.utils.parseUnits("100", dec_points).toString()); //n%

            await truffleAssert.reverts(pugg_swap.withdraw_p(3, {from:node2}),
            "caller is not project");
            await truffleAssert.reverts(pugg_swap.withdraw_p(3, {from:project}),
            "type is error");

            await pugg_swap.withdraw_p(0, {from:project});
            var project_balance = await pugg_swap.project_balance();
            var project_points = await pugg_swap.project_points();
            assert.equal(project_balance.toString(), ethers.utils.parseUnits("0", dec_base).toString());    //50%
            assert.equal(project_points.toString(), ethers.utils.parseUnits("100", dec_points).toString()); //n%
            assert.equal((await base_token.balanceOf(project)).toString(), ethers.utils.parseUnits("5", dec_base).toString());

            await pugg_swap.withdraw_p(1, {from:project});
            var project_balance = await pugg_swap.project_balance();
            var project_points = await pugg_swap.project_points();
            assert.equal(project_balance.toString(), ethers.utils.parseUnits("0", dec_base).toString());    //50%
            assert.equal(project_points.toString(), ethers.utils.parseUnits("0", dec_points).toString()); //n%
            assert.equal((await base_token.balanceOf(project)).toString(), ethers.utils.parseUnits("5", dec_base).toString());
            assert.equal((await points_token.balanceOf(project)).toString(), ethers.utils.parseUnits("100", dec_points).toString());
        });
    });
});