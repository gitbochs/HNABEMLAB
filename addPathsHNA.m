function addPathsHNA(  )

    folder = fileparts(which('addPathsHNA')); 
    cd(folder);
    addpath(genpath('src'));
    
    %now add the NSD45 bits
    addpath(genpath('src/NSD'));
end