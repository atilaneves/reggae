module tests.it.runtime;

public import tests.it;
public import tests.utils;
import reggae.reggae;

// calls reggae.run, which is basically main, but with a
// fake file
auto testRun(string[] args) {
    auto output = FakeFile();
    run(output, args);
    return output;
}
