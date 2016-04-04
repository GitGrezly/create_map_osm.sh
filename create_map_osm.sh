#!/bin/bash
start=`date +%s`
COUNTRY=`echo $1 | awk '{print tolower($0)}'`
OSM_NL_ARGS='osm_nl.args'
BOUNDSZIP='\.\.\/boundary\/bounds\.zip'
SEAZIP='\.\.\/boundary\/sea\.zip'
STYLE='\.\.\/styles\/mkgmap\-style\-sheets\-master\/styles\/Openfietsmap\ full'
TYP='40010.typ'
NSI='openfietsmap.nsi'
GEHEUGEN="4000"
LOGFILE='log.log'
case $COUNTRY in
    'netherlands')
    FID='10010' 
    HEX="271A"
    ;;

    'belgium')
    FID='20010' 
    HEX="4E2A"
    ;;
    'luxembourg')
    FID='30010' 
    HEX="753A"
    ;;
    'spain')
    FID='40010' 
    HEX="9C4A"
    ;;
    'france')
    FID='50010' 
    HEX="C35A"
    ;;
    'andorra')
    FID='60010' 
    HEX="EA6A"
    ;;
    *)
    echo "Geen (geldige) input gevonden."
    echo "Het is mogelijk te kiezen uit:"
    echo "Netherlands"
    echo "Belgium" 
    echo "Luxembourg" 
    echo "Spain" 
    echo "France"
    echo "Andorra"
    exit
    ;;
esac

if [ ! -f "$COUNTRY-latest.osm.pbf" ];
then
    wget http://download.geofabrik.de/europe/$COUNTRY-latest.osm.pbf
    wget http://download.geofabrik.de/europe/$COUNTRY.poly
fi


MAPNAME=$FID"000"
if [ -d "$COUNTRY" ];
then
    rm -rfv $COUNTRY
fi

mkdir $COUNTRY

cp -v maps/$OSM_NL_ARGS $COUNTRY/
cp -v maps/$NSI $COUNTRY/
cp typ/$TYP $COUNTRY/$FID.typ
cd $COUNTRY
echo "licentie" > license.txt
sed -i "s/>FID/$FID/g" $OSM_NL_ARGS
sed -i "s/>MAPNAME/$MAPNAME/g" $OSM_NL_ARGS
sed -i "s/>BOUNDSZIP/$BOUNDSZIP/g" $OSM_NL_ARGS
sed -i "s/>SEAZIP/$SEAZIP/g" $OSM_NL_ARGS
sed -i "s/>STYLE/$STYLE/g" $OSM_NL_ARGS

sed -i "s/>FID/$FID/g" $NSI
sed -i "s/>MAPNAME/$MAPNAME/g" $NSI
sed -i "s/>HEX/$HEX/g" $NSI
sed -i "s/>COUNTRY/$COUNTRY/g" $NSI

echo "--> Zorg voor de contouren"
cmd1="osmconvert ../maps/Hoehendaten_Freizeitkarte_EUROPE.osm.pbf -v -B=../$COUNTRY.poly -o=contours_$COUNTRY.o5m"
echo -e "Start \e[1;31m$cmd1\e[0m"
$cmd1 > $LOGFILE
echo -e "Stop \e[1;31m$cmd1\e[0m"
if [[ $? != 0 ]];
then
    fc -ln -1
    echo "Contouren is extraheren is niet gelukt"
    exit $?; 
fi

fc -ln -1
pos1=`date +%s`
runtime=$((pos1-start))

echo "--> Select $COUNTRY uit europa $runtime"
cmd2="osmconvert --drop-version contours_$COUNTRY.o5m ../$COUNTRY-latest.osm.pbf -v -B=../$COUNTRY.poly -o=$COUNTRY.osm.o5m"
echo -e "Start \e[1;31m$cmd2\e[0m"
$cmd2 >> $LOGFILE
echo -e "Stop \e[1;31m$cmd2\e[0m"
if [[ $? != 0 ]];
then
    fc -ln -1
    echo "Contouren is extraheren uit Europe map is niet gelukt"
    exit $?; 
fi


pos2=`date +%s`
runtime=$((pos2-pos1))
echo "--> Split de bestanden $runtime"
cmd3="java -Xmx"$GEHEUGEN"m -jar ../splitter-r435/splitter.jar  --output=o5m --output-dir=$COUNTRY --max-nodes=1400000 --mapid=$MAPNAME --geonames-file=../maps/cities15000.txt --polygon-file=../$COUNTRY.poly $COUNTRY.osm.o5m"
echo -e "Start \e[1;31m$cmd3\e[0m"
$cmd3 >> $LOGFILE
echo -e "Stop \e[1;31m$cmd3\e[0m"

if [[ $? != 0 ]];
then
    fc -ln -1
    echo "Het splitsen van de bestanden is niet gelukt"
    exit $?; 
fi


pos3=`date +%s`
runtime=$((pos3-pos2))
echo "--> Maak het bestand aan $runtime"
cmd4="java -Xms"$GEHEUGEN"m -Xmx"$GEHEUGEN"m -jar ../mkgmap-r3674/mkgmap.jar -c $OSM_NL_ARGS -c $COUNTRY/template.args  $FID.typ"
echo -e "Start \e[1;31m$cmd4\e[0m"
$cmd4 >> $LOGFILE
echo -e "Stop \e[1;31m$cmd4\e[0m"
if [[ $? != 0 ]];
then
    fc -ln -1
    echo "Het samenvoegen van de bestanden is niet gelukt"
    exit $?; 
fi


pos4=`date +%s`
runtime=$((pos4-pos3))
echo "--> Maak installatie bestand aan $runtime"
cmd5="makensis  $NSI"
echo -e "Start \e[1;31m$cmd5\e[0m"
$cmd5 >> $LOGFILE
echo -e "Stop \e[1;31m$cmd5\e[0m"
if [[ $? != 0 ]];
then
    fc -ln -1
    echo "Het maken van het installatie bestand is niet gelukt"
    exit $?; 
fi
