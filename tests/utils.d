module tests.utils;

import reggae;
import unit_threaded;

void shouldThrowWithMessage(E)(lazy E expr, string expectedMsg,
                               string file = __FILE__, size_t line = __LINE__) {
    string msg;
    bool threw;
    try {
        expr();
    } catch(Exception ex) {
        msg = ex.msg;
        threw = true;
    }

    if(!threw) throw new Exception("Expression did not throw. Expected msg: " ~ msg, file, line);
    msg.shouldEqual(expectedMsg);
}


void doTestBuildFor(string module_ = __MODULE__)(string[] extraArgs = []) {
    auto args = ["reggae", "--no_comp_db"] ~ extraArgs;
    auto options = getOptions(args);
    doBuildFor!(module_)(options, args);
}
