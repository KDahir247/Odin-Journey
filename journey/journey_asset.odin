package journey

import "core:sys/windows"

AssetManager :: struct{
    root : string,
    sub : [dynamic]string,
}

init_asset_manager :: proc(root : string){
}

//Look at https://gist.github.com/nickav/a57009d4fcc3b527ed0f5c9cf30618f8
//Also might use a third party job system https://github.com/jakubtomsu/jobs
//Only will work for windows calling window kernel
//Asset manager must create a seperate thread for handling hot reloading, since there will be blocking functions.
//to wait for file change event.
hot_reload :: proc(){
    // windows.ReadDirectoryChangesW()
}