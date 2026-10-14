**iaw**  
docker exec -it nimbusdocsp1 a2ensite 000-default.conf  
docker exec -it nimbusdocsp1 a2ensite nimbus1.conf  
docker exec -it nimbusdocsp1 a2ensite nimbus2.conf  
docker exec -it nimbusdocsp1 service apache2 reload  
