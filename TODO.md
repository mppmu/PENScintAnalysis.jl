TODO PENScintSignalAnalysis.jl
==============================

* Structs SimilarWaveforms and Waveform (both immutable, so they can be a bitstype when using UnsafeArrays).

* Forward functions on waveforms::Waveforms to f(waveforms.samples)

* Write a package to ease creation of custom SOA types ("CustomStructsOfArrays.jl"?).:

    * Common super-type "[Abstract]CustomStructOfArrays" for common methods?
    * Use generated functions instead of macros? Support for `uview()`?
    * Broadcast-like behaviour: Array length one implies same value for all entries.
