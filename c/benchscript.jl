
cd("../mod")

files = filter(f -> ends_with(f,"0.mod"), split(readall(`ls`)))

for f in files
    ampltime = Inf
    for i in 1:3
        t = time()
        run(`ampl $f`)
        ampltime = min(time()-t,ampltime)
    end
    nlname = string(f[1:(end-3)],"nl")
    println("### $nlname AMPL time: $ampltime")
    for i in 1:3
        run(`../c/nltest $nlname`)
    end
end


