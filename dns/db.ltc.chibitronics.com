$TTL    900
@       IN      SOA     ltc.chibitronics.com. root.ltc.chibitronics.com. (
                   2017051701           ; Serial
                          900           ; Refresh [15m]
                          600           ; Retry   [10m]
                         3600           ; Expire  [1h]
                          300 )         ; Negative Cache TTL [5m]
;
@       IN      NS      ltc.chibitronics.com.
@       IN      MX      10 ltc.chibitronics.com.
@       IN      A       52.14.104.225
www     IN      A       52.14.104.225
le      IN      A       188.166.197.248
