use std::array;
use std::utils::unchanged_until;

// Implements the Poseidon permutation for the BN254 curve.
// Note that this relies on the trace table being non-wrapping, so it will
// only work with the Halo2 backend (which is the only backend that supports
// the BN254 curve).
machine PoseidonBN254 with
    latch: FIRSTBLOCK,
    operation_id: operation_id,
    // Allow this machine to be connected via a permutation
    call_selectors: sel,
{

    // Hashes two "rate" elements and one "capacity" element to one field element
    // by applying the Poseidon permutation and returning the first rate element.
    // When the hash function is used only once, the capacity element should be
    // set to a constant, where different constants can be used to define different
    // hash functions.
    operation poseidon_permutation<0> state[0], state[1], state[2] -> output[0];

    col witness operation_id;

    // Using parameters from https://eprint.iacr.org/2019/458.pdf
    // See https://extgit.iaik.tugraz.at/krypto/hadeshash/-/blob/master/code/poseidonperm_x5_254_3.sage

    // The PIL is heavily inspired by Polygon's Poseidon PIL:
    // https://github.com/0xPolygonHermez/zkevm-proverjs/blob/main/pil/poseidong.pil

    // Number of field elements in the state
    let STATE_SIZE: int = 3;
    // Number of output elements
    let OUTPUT_SIZE: int = 1;
    // Number of full rounds
    let FULL_ROUNDS: int = 8;
    // Number of partial rounds (half of them before and half of them after the full rounds)
    let PARTIAL_ROUNDS = 57;
    let ROWS_PER_HASH = FULL_ROUNDS + PARTIAL_ROUNDS + 1;

    pol constant L0 = [1] + [0]*;
    pol constant FIRSTBLOCK(i) { if i % ROWS_PER_HASH == 0 { 1 } else { 0 } };
    pol constant LASTBLOCK(i) { if i % ROWS_PER_HASH == ROWS_PER_HASH - 1 { 1 } else { 0 } };
    // Like LASTBLOCK, but also 1 in the last row of the table
    // Specified this way because we can't access the degree in the match statement
    pol constant LAST = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]* + [1];

    // Whether the current round is a partial round
    pol constant PARTIAL = [0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0]*;

    // Utility method needed until the parser can parse large numbers outside the current field.
    // Takes a list of 8 u32 numbers and returns a u256 number.
    // It is generic because it also needs to work for expr.
    let<T: FromLiteral + Mul + Add> bn: T, T, T, T, T, T, T, T -> T = |a1, a2, a3, a4, a5, a6, a7, a8| array::fold(
        [a1, a2, a3, a4, a5, a6, a7, a8],
        0,
        |acc, el| acc * 0x100000000 + el
    );
    
    // The round constants
    pol constant C_0 = [bn(0x0ee9a592, 0xba9a9518, 0xd05986d6, 0x56f40c21, 0x14c4993c, 0x11bb2993, 0x8d21d473, 0x04cd8e6e), bn(0x2f27be69, 0x0fdaee46, 0xc3ce28f7, 0x532b13c8, 0x56c35342, 0xc84bda6e, 0x20966310, 0xfadc01d0), bn(0x28813dca, 0xebaeaa82, 0x8a376df8, 0x7af4a63b, 0xc8b7bf27, 0xad49c629, 0x8ef7b387, 0xbf28526d), bn(0x15b52534, 0x031ae18f, 0x7f862cb2, 0xcf7cf760, 0xab10a815, 0x0a337b1c, 0xcd99ff6e, 0x8797d428), bn(0x10520b0a, 0xb721cadf, 0xe9eff81b, 0x016fc34d, 0xc76da36c, 0x25789378, 0x17cb978d, 0x069de559), bn(0x04df5a56, 0xff95bcaf, 0xb051f7b1, 0xcd43a99b, 0xa731ff67, 0xe4703205, 0x8fe3d418, 0x5697cc7d), bn(0x052cba22, 0x55dfd00c, 0x7c483143, 0xba8d4694, 0x48e43586, 0xa9b4cd91, 0x83fd0e84, 0x3a6b9fa6), bn(0x03150b7c, 0xd6d5d17b, 0x2529d36b, 0xe0f67b83, 0x2c4acfc8, 0x84ef4ee5, 0xce15be0b, 0xfb4a8d09), bn(0x233237e3, 0x289baa34, 0xbb147e97, 0x2ebcb951, 0x6469c399, 0xfcc069fb, 0x88f9da2c, 0xc28276b5), bn(0x2a73b71f, 0x9b210cf5, 0xb1429657, 0x2c9d32db, 0xf156e2b0, 0x86ff47dc, 0x5df54236, 0x5a404ec0), bn(0x0b7475b1, 0x02a165ad, 0x7f5b18db, 0x4e1e704f, 0x52900aa3, 0x253baac6, 0x8246682e, 0x56e9a28e), bn(0x29a795e7, 0xd9802894, 0x6e947b75, 0xd54e9f04, 0x4076e87a, 0x7b2883b4, 0x7b675ef5, 0xf38bd66e), bn(0x143fd115, 0xce08fb27, 0xca38eb7c, 0xce822b45, 0x17822cd2, 0x109048d2, 0xe6d0ddcc, 0xa17d71c8), bn(0x2e4ef510, 0xff0b6fda, 0x5fa940ab, 0x4c4380f2, 0x6a6bcb64, 0xd89427b8, 0x24d6755b, 0x5db9e30c), bn(0x30509991, 0xf88da350, 0x4bbf374e, 0xd5aae2f0, 0x3448a22c, 0x76234c8c, 0x990f01f3, 0x3a735206), bn(0x2a198297, 0x9c3ff7f4, 0x3ddd543d, 0x891c2abd, 0xdd80f804, 0xc077d775, 0x039aa350, 0x2e43adef), bn(0x21576b43, 0x8e500449, 0xa151e4ee, 0xaf17b154, 0x285c68f4, 0x2d42c180, 0x8a11abf3, 0x764c0750), bn(0x162f5243, 0x967064c3, 0x90e09557, 0x7984f291, 0xafba2266, 0xc38f5abc, 0xd89be0f5, 0xb2747eab), bn(0x1d6f3477, 0x25e4816a, 0xf2ff453f, 0x0cd56b19, 0x9e1b61e9, 0xf601e9ad, 0xe5e88db8, 0x70949da9), bn(0x174ad61a, 0x1448c899, 0xa2541647, 0x4f493030, 0x1e5c4947, 0x5279e063, 0x9a616ddc, 0x45bc7b54), bn(0x2a4c4fc6, 0xec0b0cf5, 0x21957828, 0x71c6dd3b, 0x381cc65f, 0x72e02ad5, 0x27037a62, 0xaa1bd804), bn(0x00ef6533, 0x22b13d6c, 0x889bc817, 0x15c37d77, 0xa6cd267d, 0x595c4a89, 0x09a5546c, 0x7c97cff1), bn(0x2a56ef9f, 0x2c53feba, 0xdfda3357, 0x5dbdbd88, 0x5a124e27, 0x80bbea17, 0x0e456baa, 0xce0fa5be), bn(0x04c6187e, 0x41ed881d, 0xc1b239c8, 0x8f7f9d43, 0xa9f52fc8, 0xc8b6cdd1, 0xe76e4761, 0x5b51f100), bn(0x2ab35618, 0x34ca7383, 0x5ad05f5d, 0x7acb950b, 0x4a9a2c66, 0x6b9726da, 0x83223906, 0x5b7c3b02), bn(0x154ac98e, 0x01708c61, 0x1c4fa715, 0x991f0048, 0x98f57939, 0xd126e392, 0x042971dd, 0x90e81fc6), bn(0x06746a61, 0x56eba544, 0x26b9e222, 0x06f15abc, 0xa9a6f41e, 0x6f535c6f, 0x3525401e, 0xa0654626), bn(0x2b569733, 0x64c4c4f5, 0xc1a3ec4d, 0xa3cdce03, 0x8811eb11, 0x6fb3e45b, 0xc1768d26, 0xfc0b3758), bn(0x0fdc1f58, 0x548b8570, 0x1a6c5505, 0xea332a29, 0x647e6f34, 0xad4243c2, 0xea54ad89, 0x7cebe54d), bn(0x16243916, 0xd69d2ca3, 0xdfb47222, 0x24d4c462, 0xb5736649, 0x2f45e90d, 0x8a81934f, 0x1bc3b147), bn(0x05a8c4f9, 0x968b8aa3, 0xb7b478a3, 0x0f9a5b63, 0x650f19a7, 0x5e7ce11c, 0xa9fe16c0, 0xb76c00bc), bn(0x27e88d8c, 0x15f37dce, 0xe44f1e54, 0x25a51dec, 0xbd136ce5, 0x091a6767, 0xe49ec954, 0x4ccd101a), bn(0x15742e99, 0xb9bfa323, 0x157ff8c5, 0x86f5660e, 0xac678347, 0x6144cdca, 0xdf2874be, 0x45466b1a), bn(0x15a58215, 0x65cc2ec2, 0xce78457d, 0xb197edf3, 0x53b7ebba, 0x2c552337, 0x0ddccc3d, 0x9f146a67), bn(0x2ff7bc8f, 0x4380cde9, 0x97da00b6, 0x16b0fcd1, 0xaf8f0e91, 0xe2fe1ed7, 0x39883460, 0x9e0315d2), bn(0x00248156, 0x142fd037, 0x3a479f91, 0xff239e96, 0x0f599ff7, 0xe94be69b, 0x7f2a2903, 0x05e1198d), bn(0x29aba33f, 0x799fe66c, 0x2ef3134a, 0xea04336e, 0xcc37e38c, 0x1cd211ba, 0x482eca17, 0xe2dbfae1), bn(0x22cdbc8b, 0x70117ad1, 0x401181d0, 0x2e15459e, 0x7ccd426f, 0xe869c7c9, 0x5d1dd2cb, 0x0f24af38), bn(0x1166d9e5, 0x54616dba, 0x9e753eea, 0x427c17b7, 0xfecd58c0, 0x76dfe427, 0x08b08f5b, 0x783aa9af), bn(0x2af41fbb, 0x61ba8a80, 0xfdcf6fff, 0x9e3f6f42, 0x2993fe8f, 0x0a4639f9, 0x62344c82, 0x25145086), bn(0x28201a34, 0xc594dfa3, 0x4d794996, 0xc6433a20, 0xd152bac2, 0xa7905c92, 0x6c40e285, 0xab32eeb6), bn(0x0ec868e6, 0xd15e51d9, 0x644f66e1, 0xd6471a94, 0x589511ca, 0x00d29e10, 0x14390e6e, 0xe4254f5b), bn(0x0b2d722d, 0x0919a1aa, 0xd8db58f1, 0x0062a92e, 0xa0c56ac4, 0x270e822c, 0xca228620, 0x188a1d40), bn(0x0c2d0e3b, 0x5fd57549, 0x329bf688, 0x5da66b9b, 0x790b40de, 0xfd2c8650, 0x76230538, 0x1b168873), bn(0x1e6ff321, 0x6b688c3d, 0x996d7436, 0x7d5cd4c1, 0xbc489d46, 0x754eb712, 0xc243f70d, 0x1b53cfbb), bn(0x2522b60f, 0x4ea33076, 0x40a0c2dc, 0xe041fba9, 0x21ac10a3, 0xd5f096ef, 0x4745ca83, 0x8285f019), bn(0x0f9406b8, 0x296564a3, 0x7304507b, 0x8dba3ed1, 0x62371273, 0xa07b1fc9, 0x8011fcd6, 0xad72205f), bn(0x193a5676, 0x6998ee9e, 0x0a8652dd, 0x2f3b1da0, 0x362f4f54, 0xf7237954, 0x4f957ccd, 0xeefb420f), bn(0x04e11817, 0x63050e58, 0x013444db, 0xcb99f190, 0x2b11bc25, 0xd90bbdca, 0x408d3819, 0xf4fed32b), bn(0x1382edce, 0x9971e186, 0x497eadb1, 0xaeb1f52b, 0x23b4b83b, 0xef023ab0, 0xd15228b4, 0xcceca59a), bn(0x0a59a158, 0xe3eec211, 0x7e6e94e7, 0xf0e9decf, 0x18c3ffd5, 0xe1531a92, 0x19636158, 0xbbaf62f2), bn(0x13d69fa1, 0x27d83416, 0x5ad5c7cb, 0xa7ad59ed, 0x52e0b0f0, 0xe42d7fea, 0x95e1906b, 0x520921b1), bn(0x256e175a, 0x1dc07939, 0x0ecd7ca7, 0x03fb2e3b, 0x19ec6180, 0x5d4f03ce, 0xd5f45ee6, 0xdd0f69ec), bn(0x193edd8e, 0x9fcf3d76, 0x25fa7d24, 0xb598a1d8, 0x9f3362ea, 0xf4d582ef, 0xecad76f8, 0x79e36860), bn(0x10646d2f, 0x2603de39, 0xa1f4ae5e, 0x7771a64a, 0x702db6e8, 0x6fb76ab6, 0x00bf573f, 0x9010c711), bn(0x0a6abd1d, 0x833938f3, 0x3c74154e, 0x0404b4b4, 0x0a555bbb, 0xec21ddfa, 0xfd672dd6, 0x2047f01a), bn(0x161b4223, 0x2e61b84c, 0xbf1810af, 0x93a38fc0, 0xcece3d56, 0x28c92820, 0x03ebacb5, 0xc312c72b), bn(0x2c8120f2, 0x68ef054f, 0x817064c3, 0x69dda7ea, 0x908377fe, 0xaba5c4df, 0xfbda10ef, 0x58e8c556), bn(0x23ff4f9d, 0x46813457, 0xcf60d92f, 0x57618399, 0xa5e022ac, 0x321ca550, 0x854ae239, 0x18a22eea), bn(0x3050e379, 0x96596b7f, 0x81f68311, 0x431d8734, 0xdba7d926, 0xd3633595, 0xe0c0d8dd, 0xf4f0f47f), bn(0x2796ea90, 0xd269af29, 0xf5f8acf3, 0x3921124e, 0x4e4fad3d, 0xbe658945, 0xe546ee41, 0x1ddaa9cb), bn(0x054efa1f, 0x65b0fce2, 0x83808965, 0x275d877b, 0x438da23c, 0xe5b13e19, 0x63798cb1, 0x447d25a4), bn(0x1cfb5662, 0xe8cf5ac9, 0x226a80ee, 0x17b36abe, 0xcb73ab5f, 0x87e16192, 0x7b4349e1, 0x0e4bdf08), bn(0x0fa3ec5b, 0x9488259c, 0x2eb4cf24, 0x501bfad9, 0xbe2ec9e4, 0x2c5cc8cc, 0xd419d2a6, 0x92cad870), bn(0x0fe0af78, 0x58e49859, 0xe2a54d6f, 0x1ad945b1, 0x316aa24b, 0xfbdd23ae, 0x40a6d0cb, 0x70c3eab1), 0]*;
    pol constant C_1 = [bn(0x00f14452, 0x35f2148c, 0x59865871, 0x69fc1bcd, 0x887b08d4, 0xd00868df, 0x5696fff4, 0x0956e864), bn(0x2b2ae1ac, 0xf68b7b8d, 0x2416bebf, 0x3d4f6234, 0xb763fe04, 0xb8043ee4, 0x8b8327be, 0xbca16cf2), bn(0x2727673b, 0x2ccbc903, 0xf181bf38, 0xe1c1d40d, 0x20338652, 0x00c352bc, 0x150928ad, 0xddf9cb78), bn(0x0dc8fad6, 0xd9e4b35f, 0x5ed9a3d1, 0x86b79ce3, 0x8e0e8a8d, 0x1b58b132, 0xd701d4ee, 0xcf68d1f6), bn(0x1f6d4814, 0x9b8e7f7d, 0x9b257d8e, 0xd5fbbaf4, 0x29324980, 0x75fed0ac, 0xe88a9eb8, 0x1f5627f6), bn(0x0672d995, 0xf8fff640, 0x151b3d29, 0x0cedaf14, 0x8690a10a, 0x8c8424a7, 0xf6ec282b, 0x6e4be828), bn(0x0b8badee, 0x690adb8e, 0xb0bd7471, 0x2b7999af, 0x82de5570, 0x7251ad77, 0x16077cb9, 0x3c464ddc), bn(0x2cc6182c, 0x5e14546e, 0x3cf1951f, 0x17391235, 0x5374efb8, 0x3d80898a, 0xbe69cb31, 0x7c9ea565), bn(0x05c8f4f4, 0xebd4a6e3, 0xc980d316, 0x74bfbe63, 0x23037f21, 0xb34ae5a4, 0xe80c2d4c, 0x24d60280), bn(0x1ac9b041, 0x7abcc9a1, 0x935107e9, 0xffc91dc3, 0xec18f2c4, 0xdbe7f229, 0x76a760bb, 0x5c50c460), bn(0x037c2849, 0xe191ca3e, 0xdb1c5e49, 0xf6e8b891, 0x7c843e37, 0x9366f2ea, 0x32ab3aa8, 0x8d7f8448), bn(0x20439a0c, 0x84b322eb, 0x45a3857a, 0xfc18f582, 0x6e8c7382, 0xc8a1585c, 0x507be199, 0x981fd22f), bn(0x0c64cbec, 0xb1c734b8, 0x57968dbb, 0xdcf813cd, 0xf8611659, 0x323dbcbf, 0xc8432362, 0x3be9caf1), bn(0x0081c95b, 0xc43384e6, 0x63d79270, 0xc956ce3b, 0x8925b4f6, 0xd033b078, 0xb96384f5, 0x0579400e), bn(0x1c3f20fd, 0x55409a53, 0x221b7c4d, 0x49a356b9, 0xf0a1119f, 0xb2067b41, 0xa7529094, 0x424ec6ad), bn(0x1c74ee64, 0xf15e1db6, 0xfeddbead, 0x56d6d55d, 0xba431ebc, 0x396c9af9, 0x5cad0f13, 0x15bd5c91), bn(0x2f17c055, 0x9b8fe796, 0x08ad5ca1, 0x93d62f10, 0xbce8384c, 0x815f0906, 0x743d6930, 0x836d4a9e), bn(0x2b4cb233, 0xede9ba48, 0x264ecd2c, 0x8ae50d1a, 0xd7a8596a, 0x87f29f8a, 0x7777a700, 0x92393311), bn(0x204b0c39, 0x7f4ebe71, 0xebc2d8b3, 0xdf5b913d, 0xf9e6ac02, 0xb68d3132, 0x4cd49af5, 0xc4565529), bn(0x1a96177b, 0xcf4d8d89, 0xf759df4e, 0xc2f3cde2, 0xeaaa28c1, 0x77cc0fa1, 0x3a9816d4, 0x9a38d2ef), bn(0x13ab2d13, 0x6ccf37d4, 0x47e9f2e1, 0x4a7cedc9, 0x5e727f84, 0x46f6d9d7, 0xe55afc01, 0x219fd649), bn(0x0e25483e, 0x45a66520, 0x8b261d8b, 0xa74051e6, 0x400c776d, 0x652595d9, 0x845aca35, 0xd8a397d3), bn(0x1c8361c7, 0x8eb5cf5d, 0xecfb7a2d, 0x17b5c409, 0xf2ae2999, 0xa46762e8, 0xee416240, 0xa8cb9af1), bn(0x13b37bd8, 0x0f4d27fb, 0x10d84331, 0xf6fb6d53, 0x4b81c61e, 0xd1577644, 0x9e801b7d, 0xdc9c2967), bn(0x1d4d8ec2, 0x91e720db, 0x200fe6d6, 0x86c0d613, 0xacaf6af4, 0xe95d3bf6, 0x9f7ed516, 0xa597b646), bn(0x0b339d8a, 0xcca7d4f8, 0x3eedd840, 0x93aef510, 0x50b3684c, 0x88f8b0b0, 0x4524563b, 0xc6ea4da4), bn(0x0f18f5a0, 0xecd1423c, 0x496f3820, 0xc549c278, 0x38e5790e, 0x2bd0a196, 0xac917c7f, 0xf32077fb), bn(0x123769dd, 0x49d5b054, 0xdcd76b89, 0x804b1bcb, 0x8e1392b3, 0x85716a5d, 0x83feb65d, 0x437f29ef), bn(0x12373a82, 0x51fea004, 0xdf68abcf, 0x0f7786d4, 0xbceff28c, 0x5dbbe0c3, 0x944f685c, 0xc0a0b1f2), bn(0x1efbe46d, 0xd7a578b4, 0xf66f9adb, 0xc88b4378, 0xabc21566, 0xe1a0453c, 0xa13a4159, 0xcac04ac2), bn(0x20f05771, 0x2cc21654, 0xfbfe59bd, 0x345e8dac, 0x3f7818c7, 0x01b9c788, 0x2d9d57b7, 0x2a32e83f), bn(0x2feed17b, 0x84285ed9, 0xb8a5c8c5, 0xe95a41f6, 0x6e096619, 0xa7703223, 0x176c41ee, 0x433de4d1), bn(0x1aac2853, 0x87f65e82, 0xc895fc68, 0x87ddf405, 0x77107454, 0xc6ec0317, 0x284f033f, 0x27d0c785), bn(0x2411d57a, 0x4813b998, 0x0efa7e31, 0xa1db5966, 0xdcf64f36, 0x04427750, 0x2f15485f, 0x28c71727), bn(0x00b9831b, 0x94852559, 0x5ee02724, 0x471bcd18, 0x2e9521f6, 0xb7bb68f1, 0xe93be4fe, 0xbb0d3cbe), bn(0x171d5620, 0xb87bfb13, 0x28cf8c02, 0xab3f0c9a, 0x397196aa, 0x6a542c23, 0x50eb512a, 0x2b2bcda9), bn(0x1e9bc179, 0xa4fdd758, 0xfdd1bb19, 0x45088d47, 0xe70d114a, 0x03f6a0e8, 0xb5ba6503, 0x69e64973), bn(0x0ef042e4, 0x54771c53, 0x3a9f57a5, 0x5c503fce, 0xfd3150f5, 0x2ed94a7c, 0xd5ba93b9, 0xc7dacefd), bn(0x2de52989, 0x431a8595, 0x93413026, 0x354413db, 0x177fbf4c, 0xd2ac0b56, 0xf855a888, 0x357ee466), bn(0x119e684d, 0xe476155f, 0xe5a6b41a, 0x8ebc85db, 0x8718ab27, 0x889e85e7, 0x81b214ba, 0xce4827c3), bn(0x083efd7a, 0x27d17510, 0x94e80fef, 0xaf78b000, 0x864c82eb, 0x57118772, 0x4a761f88, 0xc22cc4e7), bn(0x2af33e3f, 0x86677127, 0x1ac0c9b3, 0xed2e1142, 0xecd3e74b, 0x939cd40d, 0x00d937ab, 0x84c98591), bn(0x1f790d4d, 0x7f8cf094, 0xd980ceb3, 0x7c2453e9, 0x57b54a99, 0x91ca38bb, 0xe0061d1e, 0xd6e562d4), bn(0x1162fb28, 0x689c2715, 0x4e5a8228, 0xb4e72b37, 0x7cbcafa5, 0x89e283c3, 0x5d380305, 0x4407a18d), bn(0x01ca8be7, 0x3832b8d0, 0x681487d2, 0x7d157802, 0xd741a6f3, 0x6cdc2a05, 0x76881f93, 0x26478875), bn(0x23f0bee0, 0x01b1029d, 0x5255075d, 0xdc957f83, 0x3418cad4, 0xf52b6c3f, 0x8ce16c23, 0x5572575b), bn(0x2360a8eb, 0x0cc7defa, 0x67b72998, 0xde90714e, 0x17e75b17, 0x4a52ee4a, 0xcb126c8c, 0xd995f0a8), bn(0x2a394a43, 0x934f8698, 0x2f9be56f, 0xf4fab170, 0x3b2e63c8, 0xad334834, 0xe4309805, 0xe777ae0f), bn(0x0fdb253d, 0xee83869d, 0x40c335ea, 0x64de8c5b, 0xb10eb82d, 0xb08b5e8b, 0x1f5e5552, 0xbfd05f23), bn(0x03464990, 0xf045c6ee, 0x0819ca51, 0xfd11b0be, 0x7f61b8eb, 0x99f14b77, 0xe1e66346, 0x01d9e8b5), bn(0x06ec54c8, 0x0381c052, 0xb58bf23b, 0x312ffd3c, 0xe2c4eba0, 0x65420af8, 0xf4c23ed0, 0x075fd07b), bn(0x169a177f, 0x63ea6812, 0x70b1c687, 0x7a73d21b, 0xde143942, 0xfb71dc55, 0xfd8a49f1, 0x9f10c77b), bn(0x30102d28, 0x636abd5f, 0xe5f2af41, 0x2ff6004f, 0x75cc360d, 0x3205dd2d, 0xa002813d, 0x3e2ceeb2), bn(0x18168afd, 0x34f2d915, 0xd0368ce8, 0x0b7b3347, 0xd1c7a561, 0xce611425, 0xf2664d7a, 0xa51f0b5d), bn(0x0beb5e07, 0xd1b27145, 0xf575f139, 0x5a55bf13, 0x2f90c25b, 0x40da7b38, 0x64d0242d, 0xcb1117fb), bn(0x1a679f5d, 0x36eb7b5c, 0x8ea12a4c, 0x2dedc8fe, 0xb12dffee, 0xc4503172, 0x70a6f19b, 0x34cf1860), bn(0x0ada10a9, 0x0c7f0520, 0x950f7d47, 0xa60d5e6a, 0x493f0978, 0x7f1564e5, 0xd09203db, 0x47de1a0b), bn(0x1c7c8824, 0xf758753f, 0xa57c0078, 0x9c684217, 0xb930e953, 0x13bcb73e, 0x6e7b8649, 0xa4968f70), bn(0x09945a5d, 0x147a4f66, 0xceece640, 0x5dddd9d0, 0xaf5a2c51, 0x03529407, 0xdff1ea58, 0xf180426d), bn(0x15af1169, 0x396830a9, 0x1600ca81, 0x02c35c42, 0x6ceae546, 0x1e3f95d8, 0x9d829518, 0xd30afd78), bn(0x202d7dd1, 0xda0f6b4b, 0x0325c8b3, 0x307742f0, 0x1e15612e, 0xc8e9304a, 0x7cb0319e, 0x01d32d60), bn(0x1b162f83, 0xd917e93e, 0xdb3308c2, 0x9802deb9, 0xd8aa6901, 0x13b2e148, 0x64ccf6e1, 0x8e4165f1), bn(0x0f21177e, 0x302a771b, 0xbae6d8d1, 0xecb373b6, 0x2c99af34, 0x6220ac01, 0x29c53f66, 0x6eb24100), bn(0x193c0e04, 0xe0bd2983, 0x57cb266c, 0x1506080e, 0xd36edce8, 0x5c648cc0, 0x85e8c57b, 0x1ab54bba), bn(0x216f6717, 0xbbc7dedb, 0x08536a22, 0x20843f4e, 0x2da5f1da, 0xa9ebdefd, 0xe8a5ea73, 0x44798d22), 0]*;
    pol constant C_2 = [bn(0x08dff348, 0x7e8ac99e, 0x1f29a058, 0xd0fa80b9, 0x30c72873, 0x0b7ab36c, 0xe879f389, 0x0ecf73f5), bn(0x0319d062, 0x072bef7e, 0xcca5eac0, 0x6f97d4d5, 0x5952c175, 0xab6b03ea, 0xe64b44c7, 0xdbf11cfa), bn(0x234ec45c, 0xa27727c2, 0xe74abd2b, 0x2a1494cd, 0x6efbd43e, 0x340587d6, 0xb8fb9e31, 0xe65cc632), bn(0x1bcd95ff, 0xc211fbca, 0x600f705f, 0xad3fb567, 0xea4eb378, 0xf62e1fec, 0x97805518, 0xa47e4d9c), bn(0x1d9655f6, 0x52309014, 0xd29e00ef, 0x35a2089b, 0xfff8dc1c, 0x816f0dc9, 0xca34bdb5, 0x460c8705), bn(0x099952b4, 0x14884454, 0xb21200d7, 0xffafdd5f, 0x0c9a9dcc, 0x06f2708e, 0x9fc1d820, 0x9b5c75b9), bn(0x119b1590, 0xf13307af, 0x5a1ee651, 0x020c07c7, 0x49c15d60, 0x683a8050, 0xb963d0a8, 0xe4b2bdd1), bn(0x00503255, 0x1e6378c4, 0x50cfe129, 0xa404b376, 0x4218cade, 0xdac14e2b, 0x92d2cd73, 0x111bf0f9), bn(0x0a7b1db1, 0x3042d396, 0xba05d818, 0xa319f252, 0x52bcf35e, 0xf3aeed91, 0xee1f09b2, 0x590fc65b), bn(0x12c0339a, 0xe0837482, 0x3fabb076, 0x707ef479, 0x269f3e4d, 0x6cb10434, 0x9015ee04, 0x6dc93fc0), bn(0x05a6811f, 0x8556f014, 0xe9267466, 0x1e217e9b, 0xd5206c5c, 0x93a07dc1, 0x45fdb176, 0xa716346f), bn(0x2e0ba8d9, 0x4d9ecf4a, 0x94ec2050, 0xc7371ff1, 0xbb50f277, 0x99a84b6d, 0x4a2a6f2a, 0x0982c887), bn(0x028a3058, 0x47c683f6, 0x46fca925, 0xc163ff5a, 0xe74f348d, 0x62c2b670, 0xf1426cef, 0x9403da53), bn(0x2ed5f0c9, 0x1cbd9749, 0x187e2fad, 0xe687e05e, 0xe2491b34, 0x9c039a0b, 0xba8a9f40, 0x23a0bb38), bn(0x10b4e7f3, 0xab5df003, 0x04951445, 0x9b6e18ee, 0xc46bb221, 0x3e8e131e, 0x170887b4, 0x7ddcb96c), bn(0x07533ec8, 0x50ba7f98, 0xeab9303c, 0xace01b4b, 0x9e4f2e8b, 0x82708cfa, 0x9c2fe45a, 0x0ae146a0), bn(0x2d477e38, 0x62d07708, 0xa79e8aae, 0x946170bc, 0x9775a420, 0x1318474a, 0xe665b0b1, 0xb7e2730e), bn(0x2c8fbcb2, 0xdd8573dc, 0x1dbaf8f4, 0x62285477, 0x6db2eece, 0x6d85c4cf, 0x4254e7c3, 0x5e03b07a), bn(0x0c4cb9dc, 0x3c4fd817, 0x4f1149b3, 0xc63c3c2f, 0x9ecb827c, 0xd7dc2553, 0x4ff8fb75, 0xbc79c502), bn(0x066d04b2, 0x4331d71c, 0xd0ef8054, 0xbc60c4ff, 0x05202c12, 0x6a233c1a, 0x8242ace3, 0x60b8a30a), bn(0x1121552f, 0xca260616, 0x19d24d84, 0x3dc82769, 0xc1b04fce, 0xc26f5519, 0x4c2e3e86, 0x9acc6a9a), bn(0x29f536dc, 0xb9dd7682, 0x24526465, 0x9e15d88e, 0x395ac3d4, 0xdde92d8c, 0x46448db9, 0x79eeba89), bn(0x151aff5f, 0x38b20a0f, 0xc0473089, 0xaaf0206b, 0x83e8e68a, 0x764507bf, 0xd3d0ab4b, 0xe74319c5), bn(0x01a5c536, 0x273c2d9d, 0xf578bfbd, 0x32c17b7a, 0x2ce3664c, 0x2a52032c, 0x9321ceb1, 0xc4e8a8e4), bn(0x041294d2, 0xcc484d22, 0x8f5784fe, 0x7919fd2b, 0xb9253512, 0x40a04b71, 0x1514c9c8, 0x0b65af1d), bn(0x0955e49e, 0x6610c942, 0x54a4f84c, 0xfbab3445, 0x98f0e71e, 0xaff4a7dd, 0x81ed95b5, 0x0839c82e), bn(0x04f6eeca, 0x1751f730, 0x8ac59eff, 0x5beb261e, 0x4bb56358, 0x3ede7bc9, 0x2a738223, 0xd6f76e13), bn(0x2147b424, 0xfc48c80a, 0x88ee52b9, 0x1169aace, 0xa989f644, 0x64711509, 0x94257b2f, 0xb01c63e9), bn(0x21e4f4ea, 0x5f35f85b, 0xad7ea52f, 0xf742c9e8, 0xa642756b, 0x6af44203, 0xdd8a1f35, 0xc1a90035), bn(0x07ea5e85, 0x37cf5dd0, 0x8886020e, 0x23a7f387, 0xd468d552, 0x5be66f85, 0x3b672cc9, 0x6a88969a), bn(0x04a12ede, 0xda9dfd68, 0x9672f8c6, 0x7fee3163, 0x6dcd8e88, 0xd01d4901, 0x9bd90b33, 0xeb33db69), bn(0x1ed7cc76, 0xedf45c7c, 0x40424142, 0x0f729cf3, 0x94e59429, 0x11312a0d, 0x6972b8bd, 0x53aff2b8), bn(0x25851c3c, 0x845d4790, 0xf9ddadbd, 0xb6057357, 0x832e2e7a, 0x49775f71, 0xec75a965, 0x54d67c77), bn(0x002e6f8d, 0x6520cd47, 0x13e335b8, 0xc0b6d2e6, 0x47e9a98e, 0x12f4cd25, 0x58828b5e, 0xf6cb4c9b), bn(0x0a2f5376, 0x8b8ebf6a, 0x86913b0e, 0x57c04e01, 0x1ca40864, 0x8a4743a8, 0x7d77adbf, 0x0c9c3512), bn(0x170a4f55, 0x536f7dc9, 0x70087c7c, 0x10d6fad7, 0x60c95217, 0x2dd54dd9, 0x9d1045e4, 0xec34a808), bn(0x1dd26979, 0x9b660fad, 0x58f7f489, 0x2dfb0b5a, 0xfeaad869, 0xa9c4b44f, 0x9c9e1c43, 0xbdaf8f09), bn(0x11609e06, 0xad6c8fe2, 0xf287f303, 0x6037e885, 0x1318e8b0, 0x8a0359a0, 0x3b304ffc, 0xa62e8284), bn(0x3006eb4f, 0xfc7a8581, 0x9a6da492, 0xf3a8ac1d, 0xf51aee5b, 0x17b8e89d, 0x74bf01cf, 0x5f71e9ad), bn(0x1835b786, 0xe2e8925e, 0x188bea59, 0xae363537, 0xb51248c2, 0x3828f047, 0xcff784b9, 0x7b3fd800), bn(0x0b6f88a3, 0x57719952, 0x6158e61c, 0xeea27be8, 0x11c16df7, 0x774dd851, 0x9e079564, 0xf61fd13b), bn(0x0b520211, 0xf904b5e7, 0xd09b5d96, 0x1c6ace77, 0x34568c54, 0x7dd6858b, 0x364ce5e4, 0x7951f178), bn(0x0171eb95, 0xdfbf7d1e, 0xaea97cd3, 0x85f78015, 0x0885c162, 0x35a2a6a8, 0xda92ceb0, 0x1e504233), bn(0x2f1459b6, 0x5dee441b, 0x64ad386a, 0x91e8310f, 0x282c5a92, 0xa89e1992, 0x1623ef82, 0x49711bc0), bn(0x1f773570, 0x6ffe9fc5, 0x86f976d5, 0xbdf223dc, 0x68028608, 0x0b10cea0, 0x0b9b5de3, 0x15f9650e), bn(0x2bc1ae8b, 0x8ddbb81f, 0xcaac2d44, 0x555ed568, 0x5d142633, 0xe9df905f, 0x66d94010, 0x93082d59), bn(0x15871a5c, 0xddead976, 0x804c803c, 0xbaef255e, 0xb4815a5e, 0x96df8b00, 0x6dcbbc27, 0x67f88948), bn(0x1859954c, 0xfeb8695f, 0x3e8b635d, 0xcb345192, 0x892cd112, 0x23443ba7, 0xb4166e88, 0x76c0d142), bn(0x058cbe8a, 0x9a5027bd, 0xaa4efb62, 0x3adead62, 0x75f08686, 0xf1c08984, 0xa9d7c5ba, 0xe9b4f1c0), bn(0x23f7bfc8, 0x720dc296, 0xfff33b41, 0xf98ff83c, 0x6fcab460, 0x5db2eb5a, 0xaa5bc137, 0xaeb70a58), bn(0x118872dc, 0x832e0eb5, 0x476b5664, 0x8e867ec8, 0xb09340f7, 0xa7bcb1b4, 0x962f0ff9, 0xed1f9d01), bn(0x04ef5159, 0x1c6ead97, 0xef42f287, 0xadce40d9, 0x3abeb032, 0xb922f66f, 0xfb7e9a5a, 0x7450544d), bn(0x10998e42, 0xdfcd3bbf, 0x1c0714bc, 0x73eb1bf4, 0x0443a3fa, 0x99bef4a3, 0x1fd31be1, 0x82fcc792), bn(0x29383c01, 0xebd3b6ab, 0x0c017656, 0xebe658b6, 0xa328ec77, 0xbc33626e, 0x29e2e95b, 0x33ea6111), bn(0x16d68525, 0x2078c133, 0xdc0d3eca, 0xd62b5c88, 0x30f95bb2, 0xe54b59ab, 0xdffbf018, 0xd96fa336), bn(0x0980fb23, 0x3bd456c2, 0x3974d50e, 0x0ebfde47, 0x26a423ea, 0xda4e8f6f, 0xfbc7592e, 0x3f1b93d6), bn(0x1a730d37, 0x2310ba82, 0x320345a2, 0x9ac4238e, 0xd3f07a8a, 0x2b4e121b, 0xb50ddb9a, 0xf407f451), bn(0x2cd9ed31, 0xf5f8691c, 0x8e39e407, 0x7a74faa0, 0xf400ad8b, 0x491eb3f7, 0xb47b27fa, 0x3fd1cf77), bn(0x188d9c52, 0x8025d4c2, 0xb67660c6, 0xb771b90f, 0x7c7da6ea, 0xa29d3f26, 0x8a6dd223, 0xec6fc630), bn(0x1da6d098, 0x85432ea9, 0xa06d9f37, 0xf873d985, 0xdae933e3, 0x51466b29, 0x04284da3, 0x320d8acc), bn(0x096d6790, 0xd05bb759, 0x156a952b, 0xa263d672, 0xa2d7f9c7, 0x88f4c831, 0xa29dace4, 0xc0f8be5f), bn(0x21e5241e, 0x12564dd6, 0xfd9f1cdd, 0x2a0de39e, 0xedfefc14, 0x66cc568e, 0xc5ceb745, 0xa0506edc), bn(0x16715223, 0x74606992, 0xaffb0dd7, 0xf71b12be, 0xc4236aed, 0xe6290546, 0xbcef7e1f, 0x515c2320), bn(0x102adf8e, 0xf74735a2, 0x7e912830, 0x6dcbc3c9, 0x9f6f7291, 0xcd406578, 0xce14ea2a, 0xdaba68f8), bn(0x1da55cc9, 0x00f0d21f, 0x4a3e6943, 0x91918a1b, 0x3c23b2ac, 0x773c6b3e, 0xf88e2e42, 0x28325161), 0]*;
    let C = [C_0, C_1, C_2];

    // State of the Poseidon permutation (2 rate elements and 1 capacity element)
    pol commit state[STATE_SIZE];

    // The first OUTPUT_SIZE elements of the *final* state
    // (constrained to be constant within the block and equal to parts of the state in the last row)
    pol commit output[OUTPUT_SIZE];

    // Add round constants
    let a: expr[STATE_SIZE] = array::zip(state, C, |state, C| state + C);

    // Compute S-Boxes (x^5)
    let x2: expr[STATE_SIZE] = array::map(a, |a| a * a);
    let x4: expr[STATE_SIZE] = array::map(x2, |x2| x2 * x2);
    let x5: expr[STATE_SIZE] = array::zip(x4, a, |x4, a| x4 * a);

    // Apply S-Boxes on the first element and otherwise if it is a full round.
    let b: expr[STATE_SIZE] = array::new(STATE_SIZE, |i| if i == 0 {
        x5[i]
    } else {
        PARTIAL * (a[i] - x5[i]) + x5[i]
    });

    // The MDS matrix
    let M = [
        [ bn(0x109b7f41, 0x1ba0e4c9, 0xb2b70caf, 0x5c36a7b1, 0x94be7c11, 0xad24378b, 0xfedb6859, 0x2ba8118b), bn(0x16ed41e1, 0x3bb9c0c6, 0x6ae11942, 0x4fddbcbc, 0x9314dc9f, 0xdbdeea55, 0xd6c64543, 0xdc4903e0), bn(0x2b90bba0, 0x0fca0589, 0xf617e7dc, 0xbfe82e0d, 0xf706ab64, 0x0ceb247b, 0x791a93b7, 0x4e36736d) ],
        [ bn(0x2969f27e, 0xed31a480, 0xb9c36c76, 0x4379dbca, 0x2cc8fdd1, 0x415c3dde, 0xd62940bc, 0xde0bd771), bn(0x2e2419f9, 0xec02ec39, 0x4c9871c8, 0x32963dc1, 0xb89d743c, 0x8c7b9640, 0x29b23116, 0x87b1fe23), bn(0x101071f0, 0x032379b6, 0x97315876, 0x690f053d, 0x148d4e10, 0x9f5fb065, 0xc8aacc55, 0xa0f89bfa) ],
        [ bn(0x143021ec, 0x686a3f33, 0x0d5f9e65, 0x4638065c, 0xe6cd79e2, 0x8c5b3753, 0x326244ee, 0x65a1b1a7), bn(0x176cc029, 0x695ad025, 0x82a70eff, 0x08a6fd99, 0xd057e12e, 0x58e7d7b6, 0xb16cdfab, 0xc8ee2911), bn(0x19a3fc0a, 0x56702bf4, 0x17ba7fee, 0x3802593f, 0xa6444703, 0x07043f77, 0x73279cd7, 0x1d25d5e0) ]
    ];

    // Multiply with MDS Matrix
    let dot_product = |v1, v2| array::sum(array::zip(v1, v2, |v1_i, v2_i| v1_i * v2_i));
    let c: expr[STATE_SIZE] = array::map(M, |M_row_i| dot_product(M_row_i, b));

    // Copy c to state in the next row
    array::zip(state, c, |state, c| (state' - c) * (1-LAST) = 0);

    // In the last row, the first OUTPUT_SIZE elements of the state should equal output
    array::zip(output, state, |output, state| LASTBLOCK * (output - state) = 0);

    // The output should stay constant in the block
    array::map(output, |c| unchanged_until(c, LAST));
}
