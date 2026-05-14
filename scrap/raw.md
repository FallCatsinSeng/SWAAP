<!DOCTYPE html>
<html>
<head>
	<meta charset="utf-8">
	<meta http-equiv="X-UA-Compatible" content="IE=edge">
	<title></title>
	<meta content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no" name="viewport">
	<script src="assets/js/jquery.min.js"></script>
	<script src="assets/js/bootstrap.min.js"></script>
	<script src="assets/js/adminlte.min.js"></script>
	<script type="text/javascript" src="assets/js/bootstrap-datepicker.min.js"></script>
	<script src="assets/js/jquery.dataTables.min.js"></script>
	<script src="assets/js/dataTables.bootstrap.min.js"></script>
	<script src="assets/js/sweetalert2.all.min.js"></script>
	<link rel="stylesheet" href="assets/css/semi-transparent-buttons.css">
	<link rel="stylesheet" href="assets/css/bootstrap.min.css">
	<link rel="stylesheet" href="assets/font-awesome/css/font-awesome.min.css">
			<!--<link rel="stylesheet" href="assets/css/AdminLTE.min.css">-->
		<link rel="stylesheet" href="assets/css/bootstrap-datepicker3.css"/>
	<link rel="stylesheet" href="assets/css/dataTables.bootstrap.min.css">
	<link rel="stylesheet" href="assets/css/skins/_all-skins.min.css">
	<link rel="stylesheet" href="assets/css/sweetalert2.min.css">
	<link rel="stylesheet" href="assets/css/font-gerak.min.css">
	<script>
		function show_submenu_tb_program(yid) {
			//alert(yid);
			location.replace("my_aplikasi_sub_menu.php?asal=P&id="+yid);
		}	
		function show_submenu_tb_klp_tran(yid) {
			location.replace("my_aplikasi_sub_menu.php?asal=T&id="+yid);
		}	
		function run_int_program(yid) {
			//alert(yid);
			location.replace("my_aplikasi_sub_menu.php?asal=S&id="+yid);
			/*
			$.post("me_sub_menu_program_siswa.php",
			{
				id: yid,
			},
			function(data, status){
				$('#sub_content').html(data); 
			});*/			
		}		
	</script>
	<style type="text/css">
		.footer {
			position: fixed;
			left: 0;
			bottom: 0;
			width: 100%;
			background-color: lightblue;
			color: #444;
			text-align: center;
		}  
		.centered {
			position: fixed;
			top: 50%;
			left: 50%;
			transform: translate(-50%, -50%);
			-webkit-transform: translate(-50%, -50%);
			-moz-transform: translate(-50%, -50%);
			-o-transform: translate(-50%, -50%);
			-ms-transform: translate(-50%, -50%);
		}	
		
		.fixed-panel {
			height: 100px;
			width: 100px;
			display: table-cell;
			vertical-align: middle;
			text-align: center;
		}		
		.img {
			max-width: 100%;
		}
 
		.img-responsive {
			background-color: transparant;
			background-repeat: no-repeat;
			background-position: center;
			background-size: cover;
			width: 100%;
			height:100vh;  /* responsive height */		
		}		
		
	</style>
	
	
</head>
	<body >
	<div class="container">
		<input type="hidden" name="xtemplate" id="xtemplate" value="0"/>
		<input type="hidden" name="xulang" id="xulang" value="1"/>

					<br>
			<div class="row">
				<div class="col-12 text-center">
					<img src="" style=""></img><br><i style="height:14px;">&nbsp</i><div class="box" style="border-radius:20px;background-color:red;color:yellow;margin-left:10px;margin-right:10px;"><center style="font-size:18px;">Pilihan Proses</center></div><i style="height:14px;">&nbsp</i>				</div>
			</div>
			
			<div class="row"></div>	</div>			
	</body>
</html>



<!DOCTYPE html>
<html>
<head>
	<meta charset="utf-8">
	<meta http-equiv="X-UA-Compatible" content="IE=edge">
	<title></title>
	<meta content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no" name="viewport">

	<script src="../../assets/js/jquery.min.js"></script>
	<script src="../../assets/js/bootstrap.min.js"></script>
	<script src="../../assets/js/adminlte.min.js"></script>
	<script src="../../assets/js/jquery.dataTables.min.js"></script>
	<script src="../../assets/js/dataTables.bootstrap.min.js"></script>
	<script src="../../assets/js/dataTables.keyTable.min.js"></script>
	<script type="text/javascript" src="../../assets/js/bootstrap-datepicker.min.js"></script>
	<link rel="stylesheet" href="../../assets/css/semi-transparent-buttons.css">
	<link rel="stylesheet" href="../../assets/css/bootstrap.min.css">
	<link rel="stylesheet" href="../../assets/font-awesome/css/font-awesome.min.css">
	<link rel="stylesheet" href="../../assets/css/skins/_all-skins.min.css">
	<link rel="stylesheet" href="../../assets/css/bootstrap-datepicker3.css"/>
	<link rel="stylesheet" href="../../assets/css/dataTables.bootstrap.min.css">
	<link rel="stylesheet" href="../../assets/css/keyTable.dataTables.min.css">
	<script src="../../assets/js/sweetalert2.all.min.js"></script>
	<link rel="stylesheet" href="../../assets/css/sweetalert2.min.css">

	<script type="text/javascript" charset="utf-8">
		$(document).ready(function() {
									$("#data_sekolah").load("id_kosong.php");			
						
		});
	</script>
  

</head>

<body >

	<div class="wrapper">
	<form role="form" method="post">
		<input type="hidden" name="xboleh_ujian" id="xboleh_ujian" value="<php echo $boleh_ujian;?>"/>
		<div class="row">
			<div class="col-12 text-center">
								<p style="line-height:14px;"><img src="../../" style=""></img><br><a title="Keluar dari Aplikasi" href="../../my_aplikasi_menu.php?ulang=1" class="btn btn-sm btn-success"><i class="fas fa-home"></i> Home</a></p>  
			</div>
		</div>
		<br>
			
		<!-- Content Wrapper. Contains page content -->
		<div class="content-wrapper">
			<div class="box-header" style="font-size:18px;background-color:lightgreen">
				<center>Jadwal Kuliah </center>
			</div>		
			<Br>		
			<!-- Main content -->
			<section class="content">
				<div id="data_utama">
				</div>
				<div id="data_sekolah">
				</div>
				<div id="lok_detil">
				</div>
				<div id="lok_upload">
				</div>
				<div id="focus_detil">
				</div>
				
			</section>
			<!-- /.Main content -->
		</div>
		<!-- /.Content Wrapper. Contains page content -->

	</div>
	</form>
</body>
</html>

<!DOCTYPE html>
<html>
<head>
	<meta charset="utf-8">
	<meta http-equiv="X-UA-Compatible" content="IE=edge">
	<title></title>
	<meta content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no" name="viewport">
	<script src="assets/js/jquery.min.js"></script>
	<script src="assets/js/bootstrap.min.js"></script>
	<script src="assets/js/adminlte.min.js"></script>
	<script type="text/javascript" src="assets/js/bootstrap-datepicker.min.js"></script>
	<script src="assets/js/jquery.dataTables.min.js"></script>
	<script src="assets/js/dataTables.bootstrap.min.js"></script>
	<script src="assets/js/sweetalert2.all.min.js"></script>
	<link rel="stylesheet" href="assets/css/semi-transparent-buttons.css">
	<link rel="stylesheet" href="assets/css/bootstrap.min.css">
	<link rel="stylesheet" href="assets/font-awesome/css/font-awesome.min.css">
			<!--<link rel="stylesheet" href="assets/css/AdminLTE.min.css">-->
		<link rel="stylesheet" href="assets/css/bootstrap-datepicker3.css"/>
	<link rel="stylesheet" href="assets/css/dataTables.bootstrap.min.css">
	<link rel="stylesheet" href="assets/css/skins/_all-skins.min.css">
	<link rel="stylesheet" href="assets/css/sweetalert2.min.css">
	<link rel="stylesheet" href="assets/css/font-gerak.min.css">
	<script>
		function show_submenu_tb_program(yid) {
			//alert(yid);
			location.replace("my_aplikasi_sub_menu.php?asal=P&id="+yid);
		}	
		function show_submenu_tb_klp_tran(yid) {
			location.replace("my_aplikasi_sub_menu.php?asal=T&id="+yid);
		}	
		function run_int_program(yid) {
			//alert(yid);
			location.replace("my_aplikasi_sub_menu.php?asal=S&id="+yid);
			/*
			$.post("me_sub_menu_program_siswa.php",
			{
				id: yid,
			},
			function(data, status){
				$('#sub_content').html(data); 
			});*/			
		}		
	</script>
	<style type="text/css">
		.footer {
			position: fixed;
			left: 0;
			bottom: 0;
			width: 100%;
			background-color: lightblue;
			color: #444;
			text-align: center;
		}  
		.centered {
			position: fixed;
			top: 50%;
			left: 50%;
			transform: translate(-50%, -50%);
			-webkit-transform: translate(-50%, -50%);
			-moz-transform: translate(-50%, -50%);
			-o-transform: translate(-50%, -50%);
			-ms-transform: translate(-50%, -50%);
		}	
		
		.fixed-panel {
			height: 100px;
			width: 100px;
			display: table-cell;
			vertical-align: middle;
			text-align: center;
		}		
		.img {
			max-width: 100%;
		}
 
		.img-responsive {
			background-color: transparant;
			background-repeat: no-repeat;
			background-position: center;
			background-size: cover;
			width: 100%;
			height:100vh;  /* responsive height */		
		}		
		
	</style>
	
	
</head>
	<body >
	<div class="container">
		<input type="hidden" name="xtemplate" id="xtemplate" value="0"/>
		<input type="hidden" name="xulang" id="xulang" value="1"/>

					<br>
			<div class="row">
				<div class="col-12 text-center">
					<img src="" style=""></img><br><i style="height:14px;">&nbsp</i><div class="box" style="border-radius:20px;background-color:red;color:yellow;margin-left:10px;margin-right:10px;"><center style="font-size:18px;">Pilihan Proses</center></div><i style="height:14px;">&nbsp</i>				</div>
			</div>
			
			<div class="row"></div>	</div>			
	</body>
</html>
