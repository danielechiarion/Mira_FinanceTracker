# first make sure to have the updated version of the application
dart pub global activate fastforge
echo 'export PATH="$PATH":"$HOME/.pub-cache/bin"' >> ~/.bashrc # save the tool in the path
fastforge package --platform linux --targets appimage