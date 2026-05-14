
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
	<style type="text/css"> 
		.scrl
		{
			overflow-y:auto;
			overflow-x:scroll;
		}		

		.box_menu {
		  <!--width: 175px;-->
		  width: 100%;
		  height:150px;
		  padding: 10px;
		  border: 2px solid blue;
		  background: lightblue;
		  line-height: 0.8;
		  text-align:center;
		  vertical-align:middle;
		  border-radius: 15px;
		}

	</style>	
	<script type="text/javascript" charset="utf-8">
	
		function kembaliRow1() {
			location.replace("../../my_aplikasi_menu.php?ulang=1");
		}
		
		function tampil_fa_ujian(yid) { 			// id tb_ujian_online_link_filerps
		    $('#xlok_cetak1').load("/modul_siswa/jadwal_ujian_siswa/tampilkan_file_ujian.php?id="+yid);
		}
		
		function gentoken_down_fa_ujian(yid) { 		// id tb_ujian_online_link_filerps
			$.post("/modul_siswa/jadwal_ujian_siswa/gentoken_down_file_ujian.php",
			{ id: yid},
			function(data, status){
				$("#lok_tok_"+yid).html(data);
			});
		}	
		function viewhis(y) {	
			var yidk=$("#xid_krs_"+y).val();
			var yidj=$("#xid_jadwal_"+y).val();
			var yke=$("#xke_"+y).val();
			var ykp=$("#xket_perkuliahan_"+y).val();
			var yhb=$("#xhibrid_"+y).val();
			$.post("/modul_siswa/jadwal_ujian_siswa/list_file.php",
			{
				idk: yidk,
				ke: yke,
				idj: yidj,
				kp: ykp,
				hb: yhb,
			},
			function(data, status){
				$('#xlok_cetak').html(data);
				$('#xmodal_form_cetak').modal('show');
			});			
			//alert(yidk +' | '+ yidj +' | '+ yke+' | '+ykp+' | '+yhb);
		    //$('#xlok_cetak').load("/modul_siswa/jadwal_ujian_siswa/list_file.php?idk="+yidk+"&ke="+yke+"&idj="+yidj+"&kp="+ykp+"&hb="+yhb);
            //$('#xmodal_form_cetak').modal('show');
		}
	</script>
</head>


<body >
	<Br>
	<div class="row">
		<div class="col-12 text-center">
							<p style="line-height:14px;"><img src="../../" style=""></img><br><a title="Keluar dari Aplikasi" href="../../my_aplikasi_menu.php?ulang=1" class="btn btn-sm btn-success"><i class="fas fa-home"></i> Home</a></p>  
		</div>
	</div>
	<br>
	<div class="box-header" style="font-size:18px;background-color:lightgreen">
		<center>Jadwal Kuliah </center>
	</div>		
	<div class="box scrl" style="padding:5px;">
<table style="font-size:14px;width:100%"></table>		<b style="color:blue;">klik tanggal ujian untuk melihat detil jadwal dan juga catatan dosen</b><br>
			untuk pelaksanaan kegiatan MBKM, perhatikan url <b style="color:green;">mbkm.swu.ac.id</b><Br>
		<br>
		<center>
			<a class="btn btn-info btn-md" href="javascript:kembaliRow1()">
				<i class="fa fa-arrow-left" aria-hidden="true"></i>&nbspKembali </a>
		</center>
	</div>
	<div class="modal fade" id="xmodal_form_cetak" role="dialog">
		<div class="modal-dialog modal-lg">
			<div class="modal-content">
				<div class="modal-header">
					<h5 style="color:blue;" class="modal-title"></h5>
					<button style="font-size:32px;color:red;" title="Kembali" type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
				</div>
				<div class="modal-body form">
					<div id="xlok_cetak"></div>
					<div style="background-color:#FAF0AF;">
							<p style="line-height:14px;"><br>Gunakan url <b style="color:blue">me.swu.ac.id</b> untuk <i>Upload</i> dan <i>Download</i> file berdasar token yang telah terbentuk<br>Token hanya berlaku 1 hari dalam tanggal pembentukan<br><br></p>
					</div>					
					<br>
					<div id="xlok_cetak1"></div>
					<br>
				</div>
				<br><br>
			</div>
		</div>
	</div>  	
</body>
</html>
