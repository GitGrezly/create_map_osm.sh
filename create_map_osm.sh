#!/bin/bash
JAVA='/home/dave/Downloads/jre1.8.0_91/bin/java'
start=`date +%s`
COUNTRY=`echo $1 | awk '{print tolower($0)}'`
#verander COUNTRY_MAP naar 'europe'  wil je uit de europe map de gegevens halen
#COUNTRY_MAP='europe' 
COUNTRY_MAP=$COUNTRY 
OSM_NL_ARGS='osm_nl.args'
#download van http://osm2.pleiades.uni-wuppertal.de/bounds/latest/
BOUNDSZIP='\.\.\/boundary\/bounds\.zip'
#download van http://osm2.pleiades.uni-wuppertal.de/sea/latest/
SEAZIP='\.\.\/boundary\/sea\.zip'
#download van http://develop.freizeitkarte-osm.de/ele_20_100_500/Hoehendaten_Freizeitkarte_EUROPE.osm.pbf
CONTOUR_LINES='../maps/Hoehendaten_Freizeitkarte_EUROPE.osm.pbf'
#download van http://download.geonames.org/export/dump/cities15000.zip
CITIES='../maps/cities15000.txt'
STYLE='\.\.\/styles\/mkgmap\-style\-sheets\-master\/styles\/Openfietsmap\ full'
TYP='40010.txt'
NSI='openfietsmap.nsi'
GEHEUGEN="3000"
LOGFILE='log.log'
DIR_SPLITTER='../splitter-r435'
DIR_MKGMAP='../mkgmap-r3674'
LICENTIE_TEKST='Licentie tekst'
case $COUNTRY in
    'netherlands')
    FID='25010' 
    HEX="B261"
    ;;
    'belgium')
    FID='20010' 
    HEX="2A4E"
    ;;
    'luxembourg')
    FID='30010' 
    HEX="3A75"
    ;;
    'benelux')
    FID='35010'
    HEX='C288'
    ;;
    'spain')
    FID='40010' 
    HEX="4A9C"
    ;;
    'france')
    FID='50010' 
    HEX="5AC3"
    ;;
    'andorra')
    FID='60010' 
    HEX="6AEA"
    ;;
    'germany')
    FID='61010' 
    HEX="52EE"
    ;;
    *)
    echo "Geen (geldige) input gevonden."
    echo "Het is mogelijk te kiezen uit:"
    echo "Benelux"
    echo "Netherlands"
    echo "Belgium" 
    echo "Luxembourg" 
    echo "Spain" 
    echo "France"
    echo "Andorra"
    echo "Germany"
    exit
    ;;
esac

if [ ! -f "$COUNTRY-latest.osm.pbf" ];
then
    wget http://download.geofabrik.de/europe/$COUNTRY-latest.osm.pbf
fi
if [ ! -f "$COUNTRY.poly" ];
then
wget http://download.geofabrik.de/europe/$COUNTRY.poly
fi
MAPNAME=$FID"000"
MAPID=$FID"001"

if [ -d "$COUNTRY" ];
then
    rm -rfv $COUNTRY
    #rm -vf $COUNTRY.poly*
fi

mkdir $COUNTRY

cp -v maps/$OSM_NL_ARGS $COUNTRY/
cp -v maps/$NSI $COUNTRY/
cp -v typ/$TYP $COUNTRY/$FID.txt

cd $COUNTRY
echo $LICENTIE_TEKST > license.txt
sed -i "s/>FID/$FID/g" $OSM_NL_ARGS
sed -i "s/>MAPNAME/$MAPNAME/g" $OSM_NL_ARGS
sed -i "s/>BOUNDSZIP/$BOUNDSZIP/g" $OSM_NL_ARGS
sed -i "s/>SEAZIP/$SEAZIP/g" $OSM_NL_ARGS
sed -i "s/>STYLE/$STYLE/g" $OSM_NL_ARGS
sed -i "s/>COUNTRY/$COUNTRY/g" $OSM_NL_ARGS

sed -i "s/>FID/$FID/g" $NSI
sed -i "s/>MAPNAME/$MAPNAME/g" $NSI
sed -i "s/>HEX/$HEX/g" $NSI
sed -i "s/>COUNTRY/$COUNTRY/g" $NSI

sed -i "s/>FID/$FID/g" $FID.txt

echo "--> Zorg voor de contouren"
cmd1="osmconvert $CONTOUR_LINES -v -B=../$COUNTRY.poly -o=contours_$COUNTRY.o5m"
echo -e "Start \e[1;31m$cmd1\e[0m"
echo "$cmd1" >> $LOGFILE 2>&1
$cmd1 > $LOGFILE 2>&1
if [[ $? != 0 ]];
then
    fc -ln -1
    echo "Contouren is extraheren is niet gelukt"
    exit $?; 
fi
echo -e "Stop \e[1;31m$cmd1\e[0m"

fc -ln -1
pos1=`date +%s`
runtime=$((pos1-start))

echo "--> Select $COUNTRY uit europa $runtime"
cmd2="osmconvert --drop-version contours_$COUNTRY.o5m ../$COUNTRY_MAP-latest.osm.pbf -v -B=../$COUNTRY.poly -o=$COUNTRY.osm.o5m"
echo -e "Start \e[1;31m$cmd2\e[0m"
echo "$cmd2" >> $LOGFILE 2>&1
$cmd2 >> $LOGFILE 2>&1
if [[ $? != 0 ]];
then
    fc -ln -1
    echo "Contouren is extraheren uit Europe map is niet gelukt"
    exit $?; 
fi
echo -e "Stop \e[1;31m$cmd2\e[0m"

pos2=`date +%s`
runtime=$((pos2-pos1))
echo "--> Split de bestanden $runtime"
cmd3="$JAVA -Xmx"$GEHEUGEN"m -jar $DIR_SPLITTER/splitter.jar  --output=o5m --output-dir=$COUNTRY --max-nodes=1400000 --mapid=$MAPID --geonames-file=$CITIES --polygon-file=../$COUNTRY.poly $COUNTRY.osm.o5m"
echo -e "Start \e[1;31m$cmd3\e[0m"
echo "$cmd3" >> $LOGFILE 2>&1
$cmd3 >> $LOGFILE
if [[ $? != 0 ]];
then
    fc -ln -1
    echo "Het splitsen van de bestanden is niet gelukt"
    exit $?; 
fi
echo -e "Stop \e[1;31m$cmd3\e[0m"

pos3=`date +%s`
runtime=$((pos3-pos2))
echo "--> Maak het bestand aan $runtime"
cmd4="$JAVA -Xms"$GEHEUGEN"m -Xmx"$GEHEUGEN"m -jar $DIR_MKGMAP/mkgmap.jar -c $OSM_NL_ARGS -c $COUNTRY/template.args  $FID.txt"
echo -e "Start \e[1;31m$cmd4\e[0m"
echo "$cmd4" >> $LOGFILE 2>&1
$cmd4 >> $LOGFILE
if [[ $? != 0 ]];
then
    fc -ln -1
    echo "Het samenvoegen van de bestanden is niet gelukt"
    exit $?; 
fi
echo -e "Stop \e[1;31m$cmd4\e[0m"


pos4=`date +%s`
runtime=$((pos4-pos3))
echo "--> Maak installatie bestand aan $runtime"
cmd5="makensis  $NSI"
echo -e "Start \e[1;31m$cmd5\e[0m"
echo "$cmd5" >> $LOGFILE 2>&1
$cmd5 >> $LOGFILE
if [[ $? != 0 ]];
then
    fc -ln -1
    echo "Het maken van het installatie bestand is niet gelukt"
    exit $?; 
fi
echo -e "Stop \e[1;31m$cmd5\e[0m"