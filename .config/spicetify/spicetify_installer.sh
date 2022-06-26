#!/bin/sh

# Need W and R for spicetify
sudo chmod a+wr /opt/spotify
sudo chmod a+wr /opt/spotify/Apps -R

# git clone theme repo
git clone https://github.com/spicetify/spicetify-themes.git ~/Downloads/spicetify-themes

# copy repo into Themes folder
cd spicetify-themes
cp -r * ~/.config/spicetify/Themes

# copy Extensions
cd "$(dirname "$(spicetify -c)")/Themes/Dribbblish"
mkdir -p ../../Extensions
cp dribbblish.js ../../Extensions/.
spicetify config extensions dribbblish.js
spicetify config inject_css 1 replace_colors 1 overwrite_assets 1

spicetify config current_theme Dribbblish
spicetify config color_scheme Purple
spicetify backup apply
