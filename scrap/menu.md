GET /my_aplikasi_menu.php?ulang=1&awal=0 HTTP/1.1
Host: smartone.smart-service.co.id
Sec-Ch-Ua: "Google Chrome";v="143", "Chromium";v="143", "Not A(Brand";v="24"
Cookie: PHPSESSID=eb0t3gul8oa08344r6u5rbgck1
Sec-Ch-Ua-Mobile: ?1
Sec-Ch-Ua-Platform: "Android"
Upgrade-Insecure-Requests: 1
User-Agent: Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Mobile Safari/537.36
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7
Sec-Fetch-Site: same-origin
Sec-Fetch-Mode: navigate
Sec-Fetch-Dest: document
Referer: https://smartone.smart-service.co.id/login_proses.php
Accept-Encoding: gzip, deflate, br, zstd
Accept-Language: en-US,en;q=0.9
Priority: u=0, i




HTTP/1.1 200 
Server: nginx
Date: Sun, 26 Apr 2026 13:03:44 GMT
Content-Type: text/html; charset=UTF-8
Vary: Accept-Encoding
Expires: Thu, 19 Nov 1981 08:52:00 GMT
Cache-Control: no-store, no-cache, must-revalidate, post-check=0, pre-check=0
Pragma: no-cache
Strict-Transport-Security: max-age=31536000
Alt-Svc: quic=":443"; h3=":443"; h3-29=":443"; h3-27=":443";h3-25=":443"; h3-T050=":443"; h3-Q050=":443";h3-Q049=":443";h3-Q048=":443"; h3-Q046=":443"; h3-Q043=":443"
Content-Encoding: gzip

<textarea hidden rows="5" id="xttd_mhs">
</textarea>
<textarea hidden rows="5" id="xttd_wali">
</textarea>
<input type="hidden" name="xt" id="xt" value="0"/>
<input type="hidden" name="ul" id="ul" value="1"/>
<input type="hidden" id="xbs_clear_mhs" value="0"/>
<input type="hidden" id="xbs_clear_wali" value="0"/>
<html>
  <head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <title>
    </title>
    <meta content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no" name="viewport">
    <!--<script src="assets/js/jquery.min.js">
  </script>-->
  <script src="assets/js/bootstrap.min.js">
  </script>
  <link rel="stylesheet" href="assets/css/bootstrap.min.css">
  <script src="assets/js/sweetalert2.all.min.js">
  </script>
  <link rel="stylesheet" href="assets/css/sweetalert2.min.css">
  <link rel="stylesheet" href="assets/font-awesome/css/font-awesome.min.css">
  <link href="assets/sign/jquery-ui.css" rel="stylesheet">
  <link href="assets/sign/jquery.signature/jquery.signature.css" rel="stylesheet">
  <style> #sign,#prev{ width: 200px; height: 100px; } </style>
    <!--[if IE]>
    <script src="excanvas.js">
    </script>
    <![endif]-->
    <script src="assets/sign/jquery-3.0.0.js">
    </script>
    <script src="assets/sign/jquery-ui.js">
    </script>
    <script src="assets/sign/jquery.signature/jquery.signature.js">
    </script>
    <script src="assets/sign/jquery.ui.touch-punch.js">
    </script>
    <script> $(function() { $('#sign').signature({disabled: true}); var output = $('#xttd_mhs').val(); $('#sign').signature('draw', output); $('#prev').signature({disabled: true}); var outputx = $('#xttd_wali').val(); $('#prev').signature('draw', outputx); }); function clearttd() { $('#sign').signature('clear'); } function clearttdw() { $('#prev').signature('clear'); } function save() { var xt=$("#xt").val(); var ul=$("#ul").val(); var xpakta1 = $('#xpakta1').val(); var xpakta2 = $('#xpakta2').val(); var xpakta3 = $('#xpakta3').val(); var xpakta4 = $('#xpakta4').val(); var output = $('#sign').signature('toJSON'); var outputx = $('#prev').signature('toJSON'); if (output=='{"lines":[]}' || output=='') { swal("Maaf","Tanda Tangan masih kosong","warning"); } else { $.post("post_pakta.php", { ttd_mhs: output, ttd_wali: outputx, pakta1: xpakta1, pakta2: xpakta2, pakta3: xpakta3, pakta4: xpakta4, bersedia: $("#xbersedia").val(), tgl_ttd: $("#xtgl_ttd").val(), bs_clear_mhs: $("#xbs_clear_mhs").val(), bs_clear_wali: $("#xbs_clear_wali").val(), }, function(data, status){ //swal("",data,"warning"); if (data==1) { // oke location.replace('my_aplikasi_menu_'+xt+'.php?ulang='+ul); } }); } } </script>
    </head>
    <body>
      <script>location.replace('my_aplikasi_menu_0.php?ulang=1');</script>
      </body>
    </html>