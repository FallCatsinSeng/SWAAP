POST /login_proses.php HTTP/1.1
Host: smartone.smart-service.co.id
Content-Length: 49
Cookie: PHPSESSID=eb0t3gul8oa08344r6u5rbgck1
Cache-Control: max-age=0
Sec-Ch-Ua: "Google Chrome";v="143", "Chromium";v="143", "Not A(Brand";v="24"
Sec-Ch-Ua-Mobile: ?1
Sec-Ch-Ua-Platform: "Android"
Origin: https://smartone.smart-service.co.id
Content-Type: application/x-www-form-urlencoded
Upgrade-Insecure-Requests: 1
User-Agent: Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Mobile Safari/537.36
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7
Sec-Fetch-Site: same-origin
Sec-Fetch-Mode: navigate
Sec-Fetch-User: ?1
Sec-Fetch-Dest: document
Referer: https://smartone.smart-service.co.id/smart_school_biasa_2019.php
Accept-Encoding: gzip, deflate, br, zstd
Accept-Language: en-US,en;q=0.9
Priority: u=0, i

mac_addr=&username=STI202303534&password=75998751








HTTP/1.1 200 
Server: nginx
Date: Sun, 26 Apr 2026 13:02:52 GMT
Content-Type: text/html; charset=UTF-8
Vary: Accept-Encoding
Expires: Thu, 19 Nov 1981 08:52:00 GMT
Cache-Control: no-store, no-cache, must-revalidate, post-check=0, pre-check=0
Pragma: no-cache
Strict-Transport-Security: max-age=31536000
Alt-Svc: quic=":443"; h3=":443"; h3-29=":443"; h3-27=":443";h3-25=":443"; h3-T050=":443"; h3-Q050=":443";h3-Q049=":443";h3-Q048=":443"; h3-Q046=":443"; h3-Q043=":443"
Content-Encoding: gzip

<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <title>
    </title>
    <meta content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no" name="viewport">
    <script src="assets/js/jquery.min.js">
    </script>
    <script src="assets/js/bootstrap.min.js">
    </script>
    <script src="assets/js/adminlte.min.js">
    </script>
    <script type="text/javascript" src="assets/js/bootstrap-datepicker.min.js">
    </script>
    <script src="assets/js/jquery.dataTables.min.js">
    </script>
    <script src="assets/js/dataTables.bootstrap.min.js">
    </script>
    <script src="assets/js/sweetalert2.all.min.js">
    </script>
    <link rel="stylesheet" href="assets/css/semi-transparent-buttons.css">
    <link rel="stylesheet" href="assets/css/bootstrap.min.css">
    <link rel="stylesheet" href="assets/font-awesome/css/font-awesome.min.css">
    <link rel="stylesheet" href="assets/css/bootstrap-datepicker3.css"/>
    <link rel="stylesheet" href="assets/css/dataTables.bootstrap.min.css">
    <link rel="stylesheet" href="assets/css/skins/_all-skins.min.css">
    <link rel="stylesheet" href="assets/css/sweetalert2.min.css">
    <style type="text/css"> .main-footer { background: lightblue; padding: 15px; color: #444; border-top: 1px solid #d2d6de; } .footer { position: fixed; left: 0; bottom: 0; width: 100%; background-color: lightblue; color: #444; } </style>
    </head>
    <body class="hold-transition skin-blue sidebar-mini">
      <div class="wrapper">
        <form role="form" method="post">
          <html>
            <head>
              <script type="text/javascript" charset="utf-8"> //$(document).ready(function() { //	$("#lok_utama").load("masterbuku_view.php"); //}); function simpan_pRow() { $.post($("#zlok_menu").val() +"simpan_pass.php", { mewajibkan_mac: $("#zmewajibkan_mac").val(), usr_lama: $("#zusr_lama").val(), usr_baru: $("#zusr_baru").val(), usr_baru1: $("#zusr_baru1").val(), pwd_lama: $("#zpwd_lama").val(), pwd_baru: $("#zpwd_baru").val(), pwd_baru1: $("#zpwd_baru1").val() }, function(data, status){ swal(data , "" , "success"); $("#myModal_passX").modal("hide"); }); } function baca_pesan(id) { ylok_header=$("#zlok_header").val(); $.post($("#zlok_menu").val() +"baca_pesan.php", { id_pesan: id }, function(data, status){ alert(data); $("#myModal_pesanX").modal("hide"); location.replace(ylok_header + "header.php"); }); } function hapus_pesanM(id) { $.post( $("#zlok_menu").val() +"hapus_pesan.php", { id_pesan: id, tb_pesan: "tb_pesan_masuk", }, function(data, status){ swal(data , "" , "success"); $("#isi_pesan_masuk").load($("#zlok_menu").val() +"isi_pesan_masuk.php"); }); } function hapus_pesanK(id) { ylok_header=$("#zlok_header").val(); $.post($("#zlok_menu").val() +"hapus_pesan.php", { id_pesan: id, tb_pesan: "tb_pesan_keluar", }, function(data, status){ swal(data , "" , "success"); $("#isi_pesan_keluar").load($("#zlok_menu").val() +"isi_pesan_keluar.php"); }); } function kirim_pesan() { yid_user_tujuan=$("#zid_user_tujuan").val(); ypesan=$("#zpesan").val(); if (ypesan=='' || yid_user_tujuan=='-2') { swal("Pengirim | Pesan Kosong" , "" , "success"); } else { $.post($("#zlok_menu").val() +"kirim_pesan.php", { id_user_tujuan: yid_user_tujuan, pesan: ypesan, }, function(data, status){ swal(data , "" , "success"); $("#isi_pesan_keluar").load($("#zlok_menu").val() +"isi_pesan_keluar.php"); }); } } function in_box() { $("#isi_pesan_masuk").load($("#zlok_menu").val() +"isi_pesan_masuk.php"); } function out_box() { $("#isi_pesan_keluar").load($("#zlok_menu").val() +"isi_pesan_keluar.php"); } function view_pdf(fl) { var lok=$("#zlok_menu").val(); window.open( lok+'pdf_view.php?file_pdf='+fl, '_blank' ); } </script>
              </head>
              <body>
                <input type="hidden" name="zlok_menu" id="zlok_menu" value="config/"/>
                <input type="hidden" name="zlok_header" id="zlok_header" value=""/>
                <!-- Modal ganti password -->
                <div class="modal fade" id="myModal_passX" role="dialog">
                  <div class="modal-dialog">
                    <!-- Modal content-->
                    <div class="modal-content">
                      <div class="modal-header">
                        <button type="button" class="close" data-dismiss="modal">Ã</button>
                          <center>
                            <h4 class="modal-title">Ganti User-Pasword</h4>
                            </center>
                          </div>
                          <div class="modal-body">
                            <div style="height:10px;" class="row">
                              <div class="col-xs-12">
                              </div>
                            </div>
                            <div class="row">
                              <div class="col-xs-3">
                                <label>User</label>
                                </div>
                                <div class="col-xs-3">
                                  <label>Lama</label>
                                  </div>
                                  <div class="col-xs-6">
                                    <input class="form-control" readonly type="text" name="zusr_lama" class="form-control" id="zusr_lama" value="">
                                  </div>
                                </div>
                                <div class="row">
                                  <div class="col-xs-3">
                                    <label>
                                    </label>
                                  </div>
                                  <div class="col-xs-3">
                                    <label>Baru</label>
                                    </div>
                                    <div class="col-xs-6">
                                      <input class="form-control" type="text" name="zusr_baru" id="zusr_baru" class="form-control" value="">
                                    </div>
                                  </div>
                                  <div class="row">
                                    <div class="col-xs-3">
                                      <label>
                                      </label>
                                    </div>
                                    <div class="col-xs-3">
                                      <label>Ulangi</label>
                                      </div>
                                      <div class="col-xs-6">
                                        <input class="form-control" type="text" name="zusr_baru1" id="zusr_baru1" class="form-control" value="">
                                      </div>
                                    </div>
                                    <div style="height:10px;" class="row">
                                      <div class="col-xs-12">
                                      </div>
                                    </div>
                                    <div class="row">
                                      <div class="col-xs-3">
                                        <label>Password</label>
                                        </div>
                                        <div class="col-xs-3">
                                          <label>Lama</label>
                                          </div>
                                          <div class="col-xs-6">
                                            <input class="form-control" type="password" name="zpwd_lama" class="form-control" id="zpwd_lama" value="">
                                          </div>
                                        </div>
                                        <div class="row">
                                          <div class="col-xs-3">
                                            <label>
                                            </label>
                                          </div>
                                          <div class="col-xs-3">
                                            <label>Baru</label>
                                            </div>
                                            <div class="col-xs-6">
                                              <input class="form-control" type="password" name="zpwd_baru" id="zpwd_baru" class="form-control" value="">
                                            </div>
                                          </div>
                                          <div class="row">
                                            <div class="col-xs-3">
                                              <label>
                                              </label>
                                            </div>
                                            <div class="col-xs-3">
                                              <label>Ulangi</label>
                                              </div>
                                              <div class="col-xs-6">
                                                <input class="form-control" type="password" name="zpwd_baru1" id="zpwd_baru1" class="form-control" value="">
                                              </div>
                                            </div>
                                          </div>
                                          <div class="modal-footer">
                                            <a href="javascript:simpan_pRow()" class="btn btn-info btn-md" >Simpan</a>
                                              <button type="button" class="btn btn-default" data-dismiss="modal">Tutup</button>
                                              </div>
                                            </div>
                                          </div>
                                        </div>
                                        <!-- /.Modal ganti password -->
                                        <!-- Modal Perpesanan -->
                                        <div class="modal fade" id="myModal_pesanX" role="dialog">
                                          <div class="modal-dialog modal-lg">
                                            <!-- Modal content-->
                                            <div class="modal-content">
                                              <div class="modal-header">
                                                <button type="button" class="close" data-dismiss="modal">Ã</button>
                                                  <center>
                                                    <h4 class="modal-title">Perpesanan Aplikasi</h4>
                                                    </center>
                                                  </div>
                                                  <div class="modal-body">
                                                    <!-- <a href="javascript:view_pdf('App_Perpustakaan_Wiber.pdf')" >
                                                    <u>view</u>
                                                    </a> -->
                                                    <a href="javascript:in_box()" >
                                                      <u>Daftar Pesan Masuk</u>
                                                      </a>
                                                      <div id="isi_pesan_masuk">
                                                      </div>
                                                    </div>
                                                    <div class="modal-footer">
                                                      <button type="button" class="btn btn-default" data-dismiss="modal">Tutup</button>
                                                      </div>
                                                    </div>
                                                  </div>
                                                </div>
                                                <!-- /.Modal Perpesanan -->
                                              </body>
                                            </html>
                                            <html>
                                              <head>
                                                <style type="text/css"> .fixed-panel { height:60px; width: 110px; min-width: 110px; display: table-cell; vertical-align: middle; background-color: green; text-align: center; border-radius:15px; } </style>
                                                  <script> function showitem(yopen) { document.location.href = yopen; } function show_submenu_tb_program(yid) { //var ywidth=$(window).width(); //location.replace("my_school_view_sub_menu.php?id="+yid+"&device_width="+ywidth); location.replace("my_aplikasi_sub_menu.php?id="+yid); } </script>
                                                  </head>
                                                  <body style="background-color:#4EA2FB;color:white;padding:0px;" >
                                                    <!-- format mobile -->
                                                    <script>location.replace('my_aplikasi_menu.php?ulang=1&awal=0'); </script>
                                                    </body>
                                                  </html>
                                                  <div class="content-wrapper">
                                                    <section class="content-header">
                                                    </section>
                                                    <section class="content">
                                                      <div id="lok_spin">
                                                      </div>
                                                    </section>
                                                  </div>
                                                </form>
                                              </div>
                                            </body>
                                          </html>