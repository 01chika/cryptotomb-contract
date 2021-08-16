const Tombs = artifacts.require("Tombs");

contract("Tombs", (accounts) => {
 let tomb;
 let expectedPlotId;

 before(async () => {
     tomb = await Tombs.deployed();
 });

 describe("get owner of CT", async () => {
    before("get owner of CT", async () => {
      //await adoption.adopt(8, { from: accounts[0] });
      expectedOwner = accounts[0];
    });
  });

//  describe("adopting a pet and retrieving account addresses", async () => {
//     before("adopt a pet using accounts[0]", async () => {
//       await adoption.adopt(8, { from: accounts[0] });
//       expectedAdopter = accounts[0];
//     });
   
    it("can get owner", async () => {
      const owner = await tomb.owner();
      assert.equal(owner, expectedOwner, "The owner of the contract should be the first account.");
    });
});