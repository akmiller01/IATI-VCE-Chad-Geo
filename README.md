# IATI-VCE-Chad-Geo

## Operation

1. Setup python virtual environment


```
python3 -m virtualenv venv
source venv/bin/activate
pip3 install -r requirements.txt
```

2. Run python extraction script

```
python3 location_parse.py
```

3. Run R code

```
Rscript chad_geo.R
```