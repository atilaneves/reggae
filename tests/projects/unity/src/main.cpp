#include <iostream>
extern int timesTwo(int);
using namespace std;
int main() {
    const int i = 3;
    cout << i << " times two is " << timesTwo(i) << endl;
}
