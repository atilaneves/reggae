module reggae.binary;

import reggae.build;

@safe:

struct Binary {
    Build build;
    string projectPath;

    void run() const {
        throw new Exception("Not implemented");
    }
}
