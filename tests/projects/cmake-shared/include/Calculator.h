#ifndef MYDLL_H
#define MYDLL_H

#if defined(_WIN32) && defined(MYDLL_EXPORTS)
    // Define MYDLL_API as dllexport when building the DLL on Windows
    #define MYDLL_API __declspec(dllexport)
#elif defined(_WIN32)
    // Define MYDLL_API as dllimport for other configurations (e.g., building a client application on Windows)
    #define MYDLL_API __declspec(dllimport)
#else
    // Define MYDLL_API as empty for non-Windows platforms
    #define MYDLL_API
#endif

// Function declarations with export declaration
MYDLL_API int add(int a, int b);
MYDLL_API int subtract(int a, int b);
MYDLL_API int multiply(int a, int b);

#endif // MYDLL_H