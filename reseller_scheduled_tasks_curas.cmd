@echo off
echo Running RCM360 stored procedures...
mysql.exe -hdbclust10 -P5648 -usite648_DbUser -ptX2JtaZ3 -D mobiledoc_648 -e "call rcm360_trendextract"
mysql.exe -hdbclust11 -P5687 -usite687_DbUser -p35sZe58v -D mobiledoc_687 -e "call rcm360_trendextract"
echo Done.
