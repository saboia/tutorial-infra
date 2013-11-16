
include "mysql"

define appdb($database, $username, $password){

	exec { "create-$database-db":
   		unless => "mysqlshow -uroot $database",
    	command => "mysqladmin -uroot create $database",
    	path => "/usr/bin",
		require => Class["mysql"],
	}

	exec { "grant-$database-db":
    	unless => "mysqlshow -u$username -p$password $database",
    	command => "mysql -uroot -e \"grant all on $database.* to '$username'@'%' identified by '$password'; grant all on $database.* to '$username'@'localhost' identified by '$password';\"",
    	path => ["/usr/bin"],
    	require => [Service["mysql"], Exec["create-$database-db"]]
	}
}