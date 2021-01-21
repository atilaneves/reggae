module tests.ut.dcompile;

import unit_threaded;
import reggae.dcompile;


version(Windows)
void testParseResponseFile() {
    parseResponseFile("abc").shouldEqual(["abc"]);
    parseResponseFile("a b\tc").shouldEqual(["a", "b", "c"]);
    parseResponseFile(" a\n b\tc\r\n").shouldEqual(["a", "b", "c"]);

    parseResponseFile(`program
                       C:\arg1
                       "C:\arg 2"
                       "arg\"3\""
                       'arg "4"'
                       /LIBPATH:"a b c"d
                       /LIBPATH:'a b'c`)
        .shouldEqual([`program`, `C:\arg1`, `C:\arg 2`, `arg"3"`, `arg "4"`, `/LIBPATH:a b cd`, `/LIBPATH:a bc`]);
}
