// CUSTOM FUNCTIONS UNTUK GOOGLE SHEETS
function CALCULATE_HPP(bahanBakuStr) {
  if (!bahanBakuStr) return 0;
  var bahanBaku = parseTextBahanBaku(bahanBakuStr);
  if (bahanBaku.length === 0) return 0;
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName('Inventory');
  if(!sheet) return 0;
  var data = sheet.getDataRange().getValues();
  var totalHpp = 0;
  for (var i = 0; i < bahanBaku.length; i++) {
    var namaItem = bahanBaku[i].nama;
    var qty = bahanBaku[i].qty;
    for (var j = 1; j < data.length; j++) {
      if (data[j][1].toString().trim().toLowerCase() === namaItem) {
        var harga = parseFloat(data[j][4]) || 0;
        totalHpp += (harga * qty);
        break;
      }
    }
  }
  return totalHpp;
}

function CALCULATE_STOK(bahanBakuStr) {
  if (!bahanBakuStr) return 999;
  var bahanBaku = parseTextBahanBaku(bahanBakuStr);
  if (bahanBaku.length === 0) return 999;
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName('Inventory');
  if(!sheet) return 0;
  var data = sheet.getDataRange().getValues();
  var minStok = null;
  for (var i = 0; i < bahanBaku.length; i++) {
    var namaItem = bahanBaku[i].nama;
    var qtyNeeded = bahanBaku[i].qty;
    for (var j = 1; j < data.length; j++) {
      if (data[j][1].toString().trim().toLowerCase() === namaItem) {
        var curStok = parseFloat(data[j][5]) || 0;
        var possible = Math.floor(curStok / qtyNeeded);
        if (minStok === null || possible < minStok) minStok = possible;
        break;
      }
    }
  }
  return minStok === null ? 0 : minStok;
}

function getOrSetupCapexOpexSheets(ss) {
  var sheetCapex = ss.getSheetByName('CAPEX');
  var sheetOpex = ss.getSheetByName('OPEX');

  // Deteksi otomatis: jika belum ada sheet CAPEX, tetapi sheet OPEX berisi kolom umur_ekonomis (aset modal)
  if (!sheetCapex && sheetOpex) {
    var headerRow = sheetOpex.getRange(1, 1, 1, Math.max(sheetOpex.getLastColumn(), 1)).getValues()[0];
    var isCapex = headerRow.some(function(col) {
      var s = col.toString().toLowerCase();
      return s.indexOf('umur') !== -1 || s.indexOf('sisa') !== -1;
    });
    if (isCapex) {
      sheetOpex.setName('CAPEX');
      sheetCapex = sheetOpex;
      sheetOpex = ss.insertSheet('OPEX');
      sheetOpex.appendRow(['id_opex', 'nama_pengeluaran', 'kategori', 'nominal', 'quantity', 'total_biaya', 'tanggal_masuk', 'waktu_masuk']);
    }
  }

  if (!sheetCapex) {
    sheetCapex = ss.insertSheet('CAPEX');
    sheetCapex.appendRow(['id_capex', 'nama_barang', 'kategori', 'harga_barang', 'umur_ekonomis', 'quantity', 'tanggal_masuk', 'waktu_masuk', 'sisa_umur']);
  }

  if (!sheetOpex) {
    sheetOpex = ss.insertSheet('OPEX');
    sheetOpex.appendRow(['id_opex', 'nama_pengeluaran', 'kategori', 'nominal', 'quantity', 'total_biaya', 'tanggal_masuk', 'waktu_masuk']);
  }

  return { capex: sheetCapex, opex: sheetOpex };
}

function doGet(e) {
  var action = (e && e.parameter) ? e.parameter.action : '';
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var _sMap = {};
  function _getSheet(name) {
    if (!_sMap[name]) _sMap[name] = ss.getSheetByName(name);
    return _sMap[name];
  }

  var sheetUsers, sheetStaff, sheetInventory, sheetTreatment, sheetCapex, sheetOpex, sheetSuplier, sheetTransaksi, sheetDetail, sheetPenggajian;

  // Load sheets lazily based on action to minimize Google Sheets RPC roundtrips
  switch(action) {
    case 'login':
      sheetUsers = _getSheet('Users');
      sheetStaff = _getSheet('Staff');
      break;
    case 'get_staff':
    case 'add_staff':
    case 'update_staff':
    case 'delete_staff':
      sheetUsers = _getSheet('Users');
      sheetStaff = _getSheet('Staff');
      break;
    case 'get_treatments':
    case 'add_treatment':
    case 'update_treatment':
    case 'delete_treatment':
      sheetTreatment = _getSheet('Treatment');
      sheetInventory = _getSheet('Inventory');
      break;
    case 'get_inventory':
    case 'add_inventory':
    case 'update_inventory':
    case 'delete_inventory':
      sheetInventory = _getSheet('Inventory');
      break;
    case 'transaksi':
    case 'transaksi_header_detail':
    case 'get_transaksi':
    case 'get_detail_transaksi':
    case 'update_status_transaksi':
      sheetTransaksi = _getSheet('Transaksi');
      sheetDetail    = _getSheet('Detail_Transaksi');
      sheetTreatment = _getSheet('Treatment');
      sheetInventory = _getSheet('Inventory');
      sheetStaff     = _getSheet('Staff');
      break;
    default:
      sheetUsers     = _getSheet('Users');
      sheetStaff     = _getSheet('Staff');
      sheetInventory = _getSheet('Inventory');
      sheetTreatment = _getSheet('Treatment');
      sheetCapex     = _getSheet('CAPEX') || _getSheet('OPEX');
      sheetOpex      = _getSheet('OPEX');
      sheetSuplier   = _getSheet('Suplier');
      sheetTransaksi = _getSheet('Transaksi');
      sheetDetail    = _getSheet('Detail_Transaksi');
      sheetPenggajian = _getSheet('Penggajian');
      break;
  }

  // ==========================================
  // 1. LOGIN
  // ==========================================
  if (action == 'login') {
    var username = e.parameter.username;
    var password = e.parameter.password;
    var usersData = sheetUsers.getDataRange().getValues();
    var staffData = sheetStaff.getDataRange().getValues();
    var userFound = false;
    var loggedInUser = {};
    for (var i = 1; i < usersData.length; i++) {
      if (usersData[i][1] == username && usersData[i][2] == password) {
        userFound = true;
        loggedInUser = { 'id_user': usersData[i][0], 'role': usersData[i][3], 'nama_lengkap': username };
        break;
      }
    }
    if (!userFound) {
      return ContentService.createTextOutput(JSON.stringify({ 'status': 'error', 'message': 'Username atau Password salah' })).setMimeType(ContentService.MimeType.JSON);
    }
    for (var j = 1; j < staffData.length; j++) {
      if (staffData[j][1] == loggedInUser.id_user) { loggedInUser.nama_lengkap = staffData[j][2]; break; }
    }
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'data': loggedInUser })).setMimeType(ContentService.MimeType.JSON);
  }

  // ==========================================
  // 2. GET STAFF
  // ==========================================
  else if (action == 'get_staff') {
    var staffData = sheetStaff.getDataRange().getValues();
    var usersData = sheetUsers.getDataRange().getValues();
    var staffList = [];
    for (var i = 1; i < staffData.length; i++) {
      var id_user = staffData[i][1]; var username = '-'; var role = '-';
      for (var j = 1; j < usersData.length; j++) {
        if (usersData[j][0] == id_user) { username = usersData[j][1]; role = usersData[j][3]; break; }
      }
      staffList.push({ 'id_staff': staffData[i][0], 'id_user': id_user, 'username': username, 'role': role,
        'nama_lengkap': staffData[i][2], 'alamat': staffData[i][3], 'status_kerja': staffData[i][4],
        'tanggal_masuk': staffData[i][5], 'jobdesk': staffData[i][6], 'masa_kerja': staffData[i][7],
        'no_telp': staffData[i][8] ? staffData[i][8].toString().trim() : '' });
    }
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'data': staffList })).setMimeType(ContentService.MimeType.JSON);
  }

  // ==========================================
  // 3. ADD STAFF
  // ==========================================
  else if (action == 'add_staff') {
    var id_user = e.parameter.id_user || ''; var id_staff = e.parameter.id_staff || '';
    var username = e.parameter.username || ''; var password = e.parameter.password || '';
    var role = e.parameter.role || 'karyawan'; var nama_lengkap = e.parameter.nama_lengkap || '';
    var alamat = e.parameter.alamat || ''; var status_kerja = e.parameter.status_kerja || '';
    var tanggal_masuk = e.parameter.tanggal_masuk || ''; var jobdesk = e.parameter.jobdesk || '';
    var masa_kerja = e.parameter.masa_kerja || '';
    var usersData = sheetUsers.getDataRange().getValues();
    for (var i = 1; i < usersData.length; i++) {
      if (usersData[i][1] == username) {
        return ContentService.createTextOutput(JSON.stringify({ 'status': 'error', 'message': 'Username sudah digunakan' })).setMimeType(ContentService.MimeType.JSON);
      }
    }
    sheetUsers.appendRow([id_user, username, password, role]);
    sheetStaff.appendRow([id_staff, id_user, nama_lengkap, alamat, status_kerja, tanggal_masuk, jobdesk, masa_kerja]);
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'message': 'Staff dan User berhasil ditambahkan' })).setMimeType(ContentService.MimeType.JSON);
  }

  // ==========================================
  // 4. CRUD INVENTORY
  // ==========================================
  else if (action == 'get_inventory') {
    var data = sheetInventory.getDataRange().getValues(); var list = [];
    for (var i = 1; i < data.length; i++) {
      list.push({ 'id_item': data[i][0], 'nama_item': data[i][1], 'jenis': data[i][2], 'satuan': data[i][3],
        'harga_satuan': data[i][4], 'stok': data[i][5], 'merk': data[i][6] || '', 'id_suplier': data[i][7] || '' });
    }
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'data': list })).setMimeType(ContentService.MimeType.JSON);
  }
  else if (action == 'add_inventory') {
    var id_item = e.parameter.id_item || ''; var nama_item = e.parameter.nama_item || '';
    var jenis = e.parameter.jenis || ''; var satuan = e.parameter.satuan || '';
    var harga_satuan = e.parameter.harga_satuan || 0; var stok = e.parameter.stok || 0;
    var merk = e.parameter.merk || ''; var id_suplier = e.parameter.id_suplier || '';
    sheetInventory.appendRow([id_item, nama_item, jenis, satuan, harga_satuan, stok, merk, id_suplier]);
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'message': 'Item berhasil ditambahkan' })).setMimeType(ContentService.MimeType.JSON);
  }
  else if (action == 'update_inventory') {
    var id_item = e.parameter.id_item; var nama_item = e.parameter.nama_item;
    var jenis = e.parameter.jenis; var satuan = e.parameter.satuan;
    var harga_satuan = e.parameter.harga_satuan; var stok = e.parameter.stok;
    var merk = e.parameter.merk || ''; var id_suplier = e.parameter.id_suplier || '';
    var data = sheetInventory.getDataRange().getValues();
    for (var i = 1; i < data.length; i++) {
      if (data[i][0] == id_item) { sheetInventory.getRange(i+1, 2, 1, 7).setValues([[nama_item, jenis, satuan, harga_satuan, stok, merk, id_suplier]]); break; }
    }
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'message': 'Inventory diupdate' })).setMimeType(ContentService.MimeType.JSON);
  }
  else if (action == 'delete_inventory') {
    var id_item = e.parameter.id_item; var data = sheetInventory.getDataRange().getValues();
    for (var i = 1; i < data.length; i++) { if (data[i][0] == id_item) { sheetInventory.deleteRow(i+1); break; } }
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'message': 'Inventory dihapus' })).setMimeType(ContentService.MimeType.JSON);
  }
  else if (action == 'restock') {
    var id_item = e.parameter.id_item || '';
    var tambah = parseFloat(e.parameter.tambah_stok) || 0;
    var harga = parseFloat(e.parameter.harga_satuan) || 0;
    var total_biaya = tambah * harga;
    var data = sheetInventory.getDataRange().getValues();
    var nama_item = '';
    for (var i = 1; i < data.length; i++) {
      if (data[i][0] == id_item) {
        nama_item = data[i][1];
        var curStok = parseFloat(data[i][5]) || 0;
        sheetInventory.getRange(i+1, 6).setValue(curStok + tambah);
        if (harga > 0) sheetInventory.getRange(i+1, 5).setValue(harga);
        break;
      }
    }
    // Catat ke Log_Restock untuk pelaporan pengeluaran
    var sheetLogRestock = ss.getSheetByName('Log_Restock');
    if (!sheetLogRestock) {
      sheetLogRestock = ss.insertSheet('Log_Restock');
      sheetLogRestock.appendRow(['id_restock', 'tanggal', 'id_item', 'nama_item', 'qty_masuk', 'harga_satuan', 'total_biaya']);
    }
    var now = new Date();
    var tglStr = Utilities.formatDate(now, "Asia/Makassar", 'yyyy-MM-dd HH:mm');
    sheetLogRestock.appendRow(['RST-' + now.getTime(), tglStr, id_item, nama_item, tambah, harga, total_biaya]);
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'message': 'Stok berhasil ditambah & tercatat di log' })).setMimeType(ContentService.MimeType.JSON);
  }
  else if (action == 'get_log_restock') {
    var sheetLogRestock = ss.getSheetByName('Log_Restock');
    if (!sheetLogRestock) return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'data': [] })).setMimeType(ContentService.MimeType.JSON);
    var data = sheetLogRestock.getDataRange().getValues();
    var list = [];
    for (var i = 1; i < data.length; i++) {
      list.push({
        'id_restock': data[i][0],
        'tanggal': data[i][1],
        'id_item': data[i][2],
        'nama_item': data[i][3],
        'qty_masuk': data[i][4],
        'harga_satuan': data[i][5],
        'total_biaya': data[i][6]
      });
    }
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'data': list })).setMimeType(ContentService.MimeType.JSON);
  }

  // ==========================================
  // 5. GET TREATMENTS (UPDATED WITH STOK)
  // ==========================================
  else if (action == 'get_treatments') {
    var data = sheetTreatment.getDataRange().getValues(); var list = [];
    for (var i = 1; i < data.length; i++) {
      list.push({ 
        'id_treatment': data[i][0], 'nama_treatment': data[i][1], 'harga_jual': data[i][2],
        'tipe_fee': data[i][3], 'nilai_fee': data[i][4], 'bahan_baku': data[i][5],
        'stok': parseFloat(data[i][12]) || 999
      });
    }
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'data': list })).setMimeType(ContentService.MimeType.JSON);
  }

  // ==========================================
  // 6. ADD TREATMENT
  // ==========================================
  else if (action == 'add_treatment') {
    var id_treatment = e.parameter.id_treatment || ''; 
    var nama_treatment = e.parameter.nama_treatment || '';
    var harga_jual = e.parameter.harga_jual || 0; 
    var tipe_fee = e.parameter.tipe_fee || '';
    var nilai_fee = e.parameter.nilai_fee || 0; 
    var bahan_baku = e.parameter.bahan_baku || '';
    
    var lastRow = sheetTreatment.getLastRow() + 1;
    var fHpp = '=CALCULATE_HPP(F' + lastRow + ')';
    var fFee = '=IF(D' + lastRow + '="Persentase"; C' + lastRow + '*(E' + lastRow + '/100); E' + lastRow + ')';
    var fTot = '=G' + lastRow + '+H' + lastRow;
    var fSel = '=C' + lastRow + '-I' + lastRow;
    var fStat = '=IF(J' + lastRow + '<0; "Rugi"; "Profit")';
    var fPer = '=IF(C' + lastRow + '=0; 0; J' + lastRow + '/C' + lastRow + ')';
    var fStok = '=CALCULATE_STOK(F' + lastRow + ')';

    sheetTreatment.appendRow([id_treatment, nama_treatment, harga_jual, tipe_fee, nilai_fee, bahan_baku, fHpp, fFee, fTot, fSel, fStat, fPer, fStok]);
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'message': 'Treatment berhasil ditambahkan' })).setMimeType(ContentService.MimeType.JSON);
  }

  // ==========================================
  // 7. UPDATE & DELETE STAFF
  // ==========================================
  else if (action == 'update_staff') {
    var id_user = e.parameter.id_user; var id_staff = e.parameter.id_staff;
    var username = e.parameter.username; var password = e.parameter.password; var role = e.parameter.role;
    var nama_lengkap = e.parameter.nama_lengkap; var alamat = e.parameter.alamat;
    var status_kerja = e.parameter.status_kerja; var tanggal_masuk = e.parameter.tanggal_masuk;
    var jobdesk = e.parameter.jobdesk; var masa_kerja = e.parameter.masa_kerja;
    var usersData = sheetUsers.getDataRange().getValues();
    for (var i = 1; i < usersData.length; i++) {
      if (usersData[i][0] == id_user) {
        if (password && password !== '') { sheetUsers.getRange(i+1, 2, 1, 3).setValues([[username, password, role]]); }
        else { sheetUsers.getRange(i+1, 2, 1, 1).setValue(username); sheetUsers.getRange(i+1, 4, 1, 1).setValue(role); }
        break;
      }
    }
    var staffData = sheetStaff.getDataRange().getValues();
    for (var j = 1; j < staffData.length; j++) {
      if (staffData[j][0] == id_staff) { sheetStaff.getRange(j+1, 3, 1, 6).setValues([[nama_lengkap, alamat, status_kerja, tanggal_masuk, jobdesk, masa_kerja]]); break; }
    }
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'message': 'Staff diupdate' })).setMimeType(ContentService.MimeType.JSON);
  }
  else if (action == 'delete_staff') {
    var id_user = e.parameter.id_user; var id_staff = e.parameter.id_staff;
    var usersData = sheetUsers.getDataRange().getValues();
    for (var i = 1; i < usersData.length; i++) { if (usersData[i][0] == id_user) { sheetUsers.deleteRow(i+1); break; } }
    var staffData = sheetStaff.getDataRange().getValues();
    for (var j = 1; j < staffData.length; j++) { if (staffData[j][0] == id_staff) { sheetStaff.deleteRow(j+1); break; } }
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'message': 'Staff dihapus' })).setMimeType(ContentService.MimeType.JSON);
  }

  // ==========================================
  // 8. UPDATE & DELETE TREATMENT
  // ==========================================
  else if (action == 'update_treatment') {
    var id_treatment = e.parameter.id_treatment; var nama_treatment = e.parameter.nama_treatment;
    var harga_jual = e.parameter.harga_jual; var tipe_fee = e.parameter.tipe_fee;
    var nilai_fee = e.parameter.nilai_fee; var bahan_baku = e.parameter.bahan_baku;
    var data = sheetTreatment.getDataRange().getValues();
    for (var i = 1; i < data.length; i++) {
      if (data[i][0] == id_treatment) { 
        var row = i + 1;
        sheetTreatment.getRange(row, 2, 1, 5).setValues([[nama_treatment, harga_jual, tipe_fee, nilai_fee, bahan_baku]]); 
        
        var fHpp = '=CALCULATE_HPP(F' + row + ')';
        var fFee = '=IF(D' + row + '="Persentase"; C' + row + '*(E' + row + '/100); E' + row + ')';
        var fTot = '=G' + row + '+H' + row;
        var fSel = '=C' + row + '-I' + row;
        var fStat = '=IF(J' + row + '<0; "Rugi"; "Profit")';
        var fPer = '=IF(C' + row + '=0; 0; J' + row + '/C' + row + ')';
        var fStok = '=CALCULATE_STOK(F' + row + ')';
        
        sheetTreatment.getRange(row, 7, 1, 7).setFormulas([[fHpp, fFee, fTot, fSel, fStat, fPer, fStok]]);
        break; 
      }
    }
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'message': 'Treatment diupdate' })).setMimeType(ContentService.MimeType.JSON);
  }
  else if (action == 'delete_treatment') {
    var id_treatment = e.parameter.id_treatment; var data = sheetTreatment.getDataRange().getValues();
    for (var i = 1; i < data.length; i++) { if (data[i][0] == id_treatment) { sheetTreatment.deleteRow(i+1); break; } }
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'message': 'Treatment dihapus' })).setMimeType(ContentService.MimeType.JSON);
  }

  // ==========================================
  // 9. CRUD CAPEX (Capital Expenditure / Aset Modal Berumur Ekonomis)
  // ==========================================
  // ==========================================
  // 9. CRUD CAPEX (Capital Expenditure / Aset Modal Berumur Ekonomis)
  // ==========================================
  else if (action == 'get_capex') {
    var pair = getOrSetupCapexOpexSheets(ss);
    var sheetC = pair.capex;
    var data = sheetC.getDataRange().getValues();
    var displayData = sheetC.getDataRange().getDisplayValues();
    var list = [];
    for (var i = 1; i < data.length; i++) {
      list.push({
        'id_capex': data[i][0],
        'nama_barang': data[i][1],
        'kategori': data[i][2],
        'harga_barang': data[i][3],
        'umur_ekonomis': data[i][4],
        'quantity': data[i][5],
        'tanggal_masuk': displayData[i][6],
        'waktu_masuk': displayData[i][7],
        'sisa_umur': displayData[i][8]
      });
    }
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'data': list })).setMimeType(ContentService.MimeType.JSON);
  }
  else if (action == 'add_capex') {
    var pair = getOrSetupCapexOpexSheets(ss);
    var sheetC = pair.capex;
    var id_capex = e.parameter.id_capex || '';
    var nama_barang = e.parameter.nama_barang || e.parameter.pengeluaran || '';
    var kategori = e.parameter.kategori || '';
    var harga_barang = parseFloat(e.parameter.harga_barang) || 0;
    var umur_ekonomis = parseInt(e.parameter.umur_ekonomis) || 1;
    var quantity = parseInt(e.parameter.quantity) || 1;
    var tanggal_masuk = e.parameter.tanggal_masuk || '';
    var waktu_masuk = e.parameter.waktu_masuk || '';
    
    sheetC.appendRow([id_capex, nama_barang, kategori, harga_barang, umur_ekonomis, quantity, tanggal_masuk, waktu_masuk, '']);
    var lastRow = sheetC.getLastRow();
    var formulaStr = '=IF(G'+lastRow+'=""; ""; MAX(0; E'+lastRow+' - DATEDIF(G'+lastRow+'; TODAY(); "M")))';
    sheetC.getRange(lastRow, 9).setValue(formulaStr);
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'message': 'CAPEX berhasil ditambahkan' })).setMimeType(ContentService.MimeType.JSON);
  }
  else if (action == 'update_capex') {
    var pair = getOrSetupCapexOpexSheets(ss);
    var sheetC = pair.capex;
    var id_capex = e.parameter.id_capex;
    var nama_barang = e.parameter.nama_barang || e.parameter.pengeluaran;
    var kategori = e.parameter.kategori;
    var harga_barang = parseFloat(e.parameter.harga_barang) || 0;
    var umur_ekonomis = parseInt(e.parameter.umur_ekonomis) || 1;
    var quantity = parseInt(e.parameter.quantity) || 1;
    var tanggal_masuk = e.parameter.tanggal_masuk || '';
    var waktu_masuk = e.parameter.waktu_masuk || '';
    var data = sheetC.getDataRange().getValues();
    for (var i = 1; i < data.length; i++) {
      if (data[i][0] == id_capex) {
        var row = i + 1;
        sheetC.getRange(row, 2, 1, 7).setValues([[nama_barang, kategori, harga_barang, umur_ekonomis, quantity, tanggal_masuk, waktu_masuk]]);
        var formulaStr = '=IF(G'+row+'=""; ""; MAX(0; E'+row+' - DATEDIF(G'+row+'; TODAY(); "M")))';
        sheetC.getRange(row, 9).setValue(formulaStr);
        break;
      }
    }
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'message': 'CAPEX diupdate' })).setMimeType(ContentService.MimeType.JSON);
  }
  else if (action == 'delete_capex') {
    var pair = getOrSetupCapexOpexSheets(ss);
    var sheetC = pair.capex;
    var id_capex = e.parameter.id_capex;
    var data = sheetC.getDataRange().getValues();
    for (var i = 1; i < data.length; i++) {
      if (data[i][0] == id_capex) {
        sheetC.deleteRow(i + 1);
        break;
      }
    }
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'message': 'CAPEX dihapus' })).setMimeType(ContentService.MimeType.JSON);
  }

  // ==========================================
  // 9B. CRUD OPEX (Operational Expenditure / Biaya Rutin Habis Pakai)
  // ==========================================
  else if (action == 'get_opex') {
    var pair = getOrSetupCapexOpexSheets(ss);
    var sheetO = pair.opex;
    
    // Safety check: jika sheet OPEX ternyata masih berisi kolom umur_ekonomis (CAPEX lama)
    var headerRow = sheetO.getRange(1, 1, 1, Math.max(sheetO.getLastColumn(), 1)).getValues()[0];
    var isCapex = headerRow.some(function(c) { 
      var s = c.toString().toLowerCase(); 
      return s.indexOf('umur') !== -1 || s.indexOf('sisa') !== -1; 
    });
    if (isCapex) {
      return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'data': [] })).setMimeType(ContentService.MimeType.JSON);
    }

    var data = sheetO.getDataRange().getValues();
    var displayData = sheetO.getDataRange().getDisplayValues();
    var list = [];
    for (var i = 1; i < data.length; i++) {
      list.push({
        'id_opex': data[i][0],
        'nama_pengeluaran': data[i][1],
        'kategori': data[i][2],
        'nominal': data[i][3],
        'quantity': data[i][4],
        'total_biaya': displayData[i][5] || (parseFloat(data[i][3]) * parseFloat(data[i][4])),
        'tanggal_masuk': displayData[i][6],
        'waktu_masuk': displayData[i][7]
      });
    }
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'data': list })).setMimeType(ContentService.MimeType.JSON);
  }
  else if (action == 'add_opex') {
    var pair = getOrSetupCapexOpexSheets(ss);
    var sheetO = pair.opex;
    var id_opex = e.parameter.id_opex || '';
    var nama_pengeluaran = e.parameter.nama_pengeluaran || e.parameter.pengeluaran || '';
    var kategori = e.parameter.kategori || 'Operasional Toko';
    var nominal = parseFloat(e.parameter.nominal) || parseFloat(e.parameter.harga_barang) || 0;
    var quantity = parseFloat(e.parameter.quantity) || 1;
    var tanggal_masuk = e.parameter.tanggal_masuk || '';
    var waktu_masuk = e.parameter.waktu_masuk || '';
    
    sheetO.appendRow([id_opex, nama_pengeluaran, kategori, nominal, quantity, '', tanggal_masuk, waktu_masuk]);
    var lastRow = sheetO.getLastRow();
    sheetO.getRange(lastRow, 6).setValue('=D' + lastRow + '*E' + lastRow);
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'message': 'OPEX berhasil ditambahkan' })).setMimeType(ContentService.MimeType.JSON);
  }
  else if (action == 'update_opex') {
    var pair = getOrSetupCapexOpexSheets(ss);
    var sheetO = pair.opex;
    var id_opex = e.parameter.id_opex;
    var nama_pengeluaran = e.parameter.nama_pengeluaran || e.parameter.pengeluaran;
    var kategori = e.parameter.kategori;
    var nominal = parseFloat(e.parameter.nominal) || parseFloat(e.parameter.harga_barang) || 0;
    var quantity = parseFloat(e.parameter.quantity) || 1;
    var tanggal_masuk = e.parameter.tanggal_masuk || '';
    var waktu_masuk = e.parameter.waktu_masuk || '';
    var data = sheetO.getDataRange().getValues();
    for (var i = 1; i < data.length; i++) {
      if (data[i][0] == id_opex) {
        var row = i + 1;
        sheetO.getRange(row, 2, 1, 7).setValues([[nama_pengeluaran, kategori, nominal, quantity, '', tanggal_masuk, waktu_masuk]]);
        sheetO.getRange(row, 6).setValue('=D' + row + '*E' + row);
        break;
      }
    }
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'message': 'OPEX diupdate' })).setMimeType(ContentService.MimeType.JSON);
  }
  else if (action == 'delete_opex') {
    var pair = getOrSetupCapexOpexSheets(ss);
    var sheetO = pair.opex;
    var id_opex = e.parameter.id_opex;
    var data = sheetO.getDataRange().getValues();
    for (var i = 1; i < data.length; i++) {
      if (data[i][0] == id_opex) {
        sheetO.deleteRow(i + 1);
        break;
      }
    }
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'message': 'OPEX dihapus' })).setMimeType(ContentService.MimeType.JSON);
  }

  // ==========================================
  // 10. CRUD SUPLIER
  // ==========================================
  else if (action == 'get_suppliers') {
    var data = sheetSuplier.getDataRange().getValues(); var list = [];
    for (var i = 1; i < data.length; i++) {
      list.push({ 'id_suplier': data[i][0], 'nama_suplier': data[i][1], 'kontak': data[i][2], 'alamat': data[i][3] });
    }
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'data': list })).setMimeType(ContentService.MimeType.JSON);
  }
  else if (action == 'add_supplier') {
    var id_suplier = e.parameter.id_suplier || ''; var nama_suplier = e.parameter.nama_suplier || '';
    var kontak = e.parameter.kontak || ''; var alamat = e.parameter.alamat || '';
    sheetSuplier.appendRow([id_suplier, nama_suplier, kontak, alamat]);
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'message': 'Suplier berhasil ditambahkan' })).setMimeType(ContentService.MimeType.JSON);
  }
  else if (action == 'update_supplier') {
    var id_suplier = e.parameter.id_suplier; var nama_suplier = e.parameter.nama_suplier;
    var kontak = e.parameter.kontak; var alamat = e.parameter.alamat;
    var data = sheetSuplier.getDataRange().getValues();
    for (var i = 1; i < data.length; i++) {
      if (data[i][0] == id_suplier) { sheetSuplier.getRange(i+1, 2, 1, 3).setValues([[nama_suplier, kontak, alamat]]); break; }
    }
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'message': 'Suplier diupdate' })).setMimeType(ContentService.MimeType.JSON);
  }
  else if (action == 'delete_supplier') {
    var id_suplier = e.parameter.id_suplier; var data = sheetSuplier.getDataRange().getValues();
    for (var i = 1; i < data.length; i++) { if (data[i][0] == id_suplier) { sheetSuplier.deleteRow(i+1); break; } }
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'message': 'Suplier dihapus' })).setMimeType(ContentService.MimeType.JSON);
  }

  // ==========================================
  // 11. ADD TRANSAKSI & INVENTORY DEDUCTION
  // ==========================================
  else if (action == 'add_transaksi') {
    var idTrx = e.parameter.id_transaksi || '';
    var kodeUnik = e.parameter.kode_unik || '';
    // Status default: Dikerjakan
    // Kolom A-M: Transaksi standar, Kolom N: Kode Unik Pelanggan
    sheetTransaksi.appendRow([
      idTrx,
      e.parameter.tanggal        || '',
      e.parameter.waktu          || '',
      e.parameter.nama_pelanggan || '',
      e.parameter.no_hp          || '',
      e.parameter.nama_kasir     || '',
      e.parameter.total_item     || 0,
      e.parameter.total_harga    || 0,
      e.parameter.metode_bayar   || '',
      e.parameter.status_bayar   || '',
      'Dikerjakan',
      '',
      '',
      kodeUnik
    ]);
    if (e.parameter.items) {
      var items = JSON.parse(e.parameter.items);
      var invData = sheetInventory.getDataRange().getValues();
      var treatmentData = sheetTreatment.getDataRange().getValues();

      for (var i = 0; i < items.length; i++) {
        var namaTreatment = items[i].nama_treatment || '';
        sheetDetail.appendRow([
          idTrx + '_' + (i + 1),
          idTrx,
          namaTreatment,
          items[i].harga_treatment || 0,
          items[i].jenis_item      || '',
          items[i].merek           || '',
          items[i].warna           || '',
          items[i].ukuran          || '',
          items[i].nama_staff      || '',
          'Belum Dibayar'
        ]);

        // Potong stok Inventory otomatis (Berdasarkan teks nama item)
        for (var t = 1; t < treatmentData.length; t++) {
          if (treatmentData[t][1] == namaTreatment) {
            var bahanBakuStr = treatmentData[t][5];
            var bahanBaku = parseTextBahanBaku(bahanBakuStr);
            for (var b = 0; b < bahanBaku.length; b++) {
              var namaItem = bahanBaku[b].nama;
              var qtyNeeded = bahanBaku[b].qty;
              for (var inv = 1; inv < invData.length; inv++) {
                if (invData[inv][1].toString().trim().toLowerCase() === namaItem) {
                  var curStok = parseFloat(invData[inv][5]) || 0;
                  var newStok = curStok - qtyNeeded;
                  sheetInventory.getRange(inv+1, 6).setValue(newStok);
                  invData[inv][5] = newStok;
                  break;
                }
              }
            }
            break;
          }
        }
      }
    }
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'message': 'Transaksi berhasil disimpan & Stok terpotong' })).setMimeType(ContentService.MimeType.JSON);
  }

  // ==========================================
  // 12. GET TRANSAKSI
  // ==========================================
  else if (action == 'get_transaksi') {
    var headerData = sheetTransaksi.getDataRange().getValues();
    var detailData = sheetDetail.getDataRange().getValues();
    var list = [];
    for (var i = 1; i < headerData.length; i++) {
      var idTrx = headerData[i][0]; var itemDetails = [];
      for (var j = 1; j < detailData.length; j++) {
        if (detailData[j][1] == idTrx) {
          itemDetails.push({
            'id_detail':       detailData[j][0],
            'nama_treatment':  detailData[j][2],
            'harga_treatment': detailData[j][3],
            'jenis_item':      detailData[j][4],
            'merek':           detailData[j][5],
            'warna':           detailData[j][6],
            'ukuran':          detailData[j][7],
            'nama_staff':      detailData[j][8] || ''
          });
        }
      }
      var kodeUnik = (headerData[i].length > 13 && headerData[i][13] !== undefined && headerData[i][13] !== null)
          ? headerData[i][13].toString()
          : '';
      list.push({
        'id_transaksi':   headerData[i][0],
        'tanggal':        headerData[i][1],
        'waktu':          headerData[i][2],
        'nama_pelanggan': headerData[i][3],
        'no_hp':          headerData[i][4],
        'nama_kasir':     headerData[i][5],
        'total_item':     headerData[i][6],
        'total_harga':    headerData[i][7],
        'metode_bayar':   headerData[i][8],
        'status_bayar':   headerData[i][9],
        'status':         headerData[i][10] || 'Dikerjakan',
        'waktu_selesai':  headerData[i][11] || '',
        'waktu_diambil':  headerData[i][12] || '',
        'kode_unik':      kodeUnik,
        'items':          itemDetails
      });
    }
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'data': list })).setMimeType(ContentService.MimeType.JSON);
  }

  // ==========================================
  // 13. UPDATE STATUS TRANSAKSI
  // ==========================================
  else if (action == 'update_status') {
    var id_transaksi = e.parameter.id_transaksi || '';
    var new_status = e.parameter.status || 'Dikerjakan';
    var metode_bayar = e.parameter.metode_bayar;
    var status_bayar = e.parameter.status_bayar;
    var data = sheetTransaksi.getDataRange().getValues();
    var updated = false;
    for (var i = 1; i < data.length; i++) {
      if (data[i][0] == id_transaksi) {
        var row = i + 1;
        sheetTransaksi.getRange(row, 11).setValue(new_status);
        if (metode_bayar && metode_bayar !== '') {
          sheetTransaksi.getRange(row, 9).setValue(metode_bayar);
        }
        if (status_bayar && status_bayar !== '') {
          sheetTransaksi.getRange(row, 10).setValue(status_bayar);
        }
        
        var now = new Date();
        // Menggunakan Waktu Indonesia Tengah (WITA - Asia/Makassar UTC+8)
        var timeStr = Utilities.formatDate(now, "Asia/Makassar", "dd-MM-yyyy HH:mm");
        if (new_status === 'Selesai') {
          sheetTransaksi.getRange(row, 12).setValue(timeStr);
        } else if (new_status === 'Diambil') {
          sheetTransaksi.getRange(row, 13).setValue(timeStr);
        }
        
        updated = true; break;
      }
    }
    if (!updated) {
      return ContentService.createTextOutput(JSON.stringify({ 'status': 'error', 'message': 'Transaksi tidak ditemukan' })).setMimeType(ContentService.MimeType.JSON);
    }
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'message': 'Status diupdate menjadi ' + new_status })).setMimeType(ContentService.MimeType.JSON);
  }

  // ==========================================
  // 14. GET PENGGAJIAN (Hitung Gaji Staff Berdasarkan Fee Treatment & Status Sepatu)
  // ==========================================
  else if (action == 'get_penggajian') {
    var detailData = sheetDetail.getDataRange().getValues();
    var treatmentData = sheetTreatment.getDataRange().getValues();
    var trxData = sheetTransaksi.getDataRange().getValues();
    
    // Peta transaksi: status pengerjaan (Dikerjakan/Selesai/Diambil) & status bayar
    var trxMap = {};
    for (var i = 1; i < trxData.length; i++) {
       var tId = trxData[i][0].toString().trim();
       trxMap[tId] = {
         'nama_pelanggan': trxData[i][3] || '-',
         'status_bayar': trxData[i][9] || 'Belum Lunas',
         'status': trxData[i][10] || 'Dikerjakan'
       };
    }

    // Peta Fee dari Sheet Treatment Kolom H (index 7)
    // Dengan fallback perhitungan langsung jika kolom H kosong / format teks
    var treatmentFeeMap = {};
    for (var t = 1; t < treatmentData.length; t++) {
      var namaT = treatmentData[t][1].toString().trim().toLowerCase();
      var feeVal = treatmentData[t][7];
      var parsedFee = 0;
      
      if (typeof feeVal === 'number' && !isNaN(feeVal) && feeVal > 0) {
        parsedFee = feeVal;
      } else if (feeVal) {
        var str = feeVal.toString().replace(/[^0-9,\.]/g, '');
        if (str.indexOf(',') > -1 && str.indexOf('.') > -1) {
          str = str.replace(/\./g, '').replace(',', '.');
        } else if (str.indexOf(',') > -1) {
          str = str.replace(',', '.');
        }
        var num = parseFloat(str);
        if (!isNaN(num) && num > 0) parsedFee = num;
      }
      
      // Fallback: hitung dari harga_jual (C) dan nilai_fee (E)
      if (parsedFee === 0) {
        var hJual = parseFloat(treatmentData[t][2]) || 0;
        var tFee = treatmentData[t][3] ? treatmentData[t][3].toString().trim() : '';
        var nFee = parseFloat(treatmentData[t][4]) || 0;
        if (tFee === 'Persentase') {
          parsedFee = hJual * (nFee / 100);
        } else {
          parsedFee = nFee;
        }
      }
      treatmentFeeMap[namaT] = parsedFee;
    }

    var staffEarnings = {};
    for (var i = 1; i < detailData.length; i++) {
      var namaStaff = detailData[i][8] ? detailData[i][8].toString().trim() : '';
      var statusGaji = detailData[i][9] ? detailData[i][9].toString().trim() : 'Belum Dibayar';
      
      if (namaStaff && statusGaji == 'Belum Dibayar') {
        var idTrx = detailData[i][1] ? detailData[i][1].toString().trim() : '';
        var idDetail = detailData[i][0] ? detailData[i][0].toString().trim() : '';
        var namaTreatment = detailData[i][2] ? detailData[i][2].toString().trim() : '';
        var fee = treatmentFeeMap[namaTreatment.toLowerCase()] || 0;
        
        var trxInfo = trxMap[idTrx] || { 'nama_pelanggan': '-', 'status_bayar': 'Belum Lunas', 'status': 'Dikerjakan' };
        var statusBayar = trxInfo.status_bayar;
        var statusTrx = trxInfo.status;
        
        // KRITERIA PIUTANG VS UANG REAL:
        // Sepatu yang belum selesai (Dikerjakan) ATAU belum diambil (Selesai tapi belum diambil pelanggan) -> MASUK PIUTANG KARYAWAN!
        // Uang Real hanya untuk sepatu yang SUDAH SELESAI & SUDAH DIAMBIL oleh pelanggan.
        var isReal = (statusTrx === 'Diambil');
        
        if (!staffEarnings[namaStaff]) {
          staffEarnings[namaStaff] = { 
             'nama_staff': namaStaff, 
             'gaji_pokok': 0, 
             'uang_real': 0, 
             'uang_piutang': 0, 
             'items': [] 
          };
        }
        
        staffEarnings[namaStaff].gaji_pokok += fee;
        if (isReal) {
           staffEarnings[namaStaff].uang_real += fee;
        } else {
           staffEarnings[namaStaff].uang_piutang += fee;
        }

        staffEarnings[namaStaff].items.push({
          'id_detail': idDetail,
          'id_transaksi': idTrx,
          'nama_pelanggan': trxInfo.nama_pelanggan,
          'nama_treatment': namaTreatment,
          'jenis_item': detailData[i][4] || '',
          'merek': detailData[i][5] || '',
          'warna': detailData[i][6] || '',
          'ukuran': detailData[i][7] || '',
          'fee': fee,
          'status_trx': statusTrx,
          'status_bayar': statusBayar,
          'is_real': isReal
        });
      }
    }
    
    // Peta data staff untuk ID & Nomor WA (Kolom I)
    var staffMap = {};
    if (sheetStaff) {
      var staffRows = sheetStaff.getDataRange().getValues();
      for (var s = 1; s < staffRows.length; s++) {
        var sNama = staffRows[s][2] ? staffRows[s][2].toString().trim().toLowerCase() : '';
        if (sNama) {
          staffMap[sNama] = {
            'id_staff': staffRows[s][0] ? staffRows[s][0].toString().trim() : '',
            'no_telp': staffRows[s][8] ? staffRows[s][8].toString().trim() : ''
          };
        }
      }
    }

    // Data master penggajian (opsional jika sheet Penggajian ada)
    var masterMap = {};
    var sheetPenggajian = ss.getSheetByName('Penggajian');
    if (sheetPenggajian) {
      var penggajianData = sheetPenggajian.getDataRange().getValues();
      for (var i = 1; i < penggajianData.length; i++) {
        masterMap[penggajianData[i][0]] = {
          'bpjstk': parseFloat(penggajianData[i][1]) || 0,
          'thr': parseFloat(penggajianData[i][2]) || 0,
          'keterlambatan': parseFloat(penggajianData[i][3]) || 0,
          'tunjangan': parseFloat(penggajianData[i][4]) || 0,
          'cashbon': parseFloat(penggajianData[i][5]) || 0,
        };
      }
    }

    var list = [];
    for (var key in staffEarnings) { 
      var earning = staffEarnings[key];
      var master = masterMap[key] || { 'bpjstk': 0, 'thr': 0, 'keterlambatan': 0, 'tunjangan': 0, 'cashbon': 0 };
      var sInfo = staffMap[key.toLowerCase()] || {};
      
      earning['id_staff'] = sInfo.id_staff || '';
      earning['no_telp'] = sInfo.no_telp || '';
      earning['tunjangan'] = master.tunjangan || 0;
      earning['cashbon'] = master.cashbon || 0;
      earning['tunjangan_bpjstk'] = master.bpjstk;
      earning['thr'] = master.thr;
      earning['potongan_keterlambatan'] = master.keterlambatan;
      earning['potongan_piutang'] = earning.uang_piutang;
      
      earning['total_penerimaan'] = earning.uang_real + earning['tunjangan'] + master.bpjstk + master.thr;
      earning['total_potongan'] = master.keterlambatan + earning['cashbon'];
      earning['total_gaji'] = earning['total_penerimaan'] - earning['total_potongan'];
      list.push(earning); 
    }
    
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'data': list })).setMimeType(ContentService.MimeType.JSON);
  }

  else if (action == 'update_penggajian_master') {
    var nama_staff = e.parameter.nama_staff;
    var bpjstk = parseFloat(e.parameter.bpjstk) || 0;
    var thr = parseFloat(e.parameter.thr) || 0;
    var keterlambatan = parseFloat(e.parameter.keterlambatan) || 0;
    var tunjangan = parseFloat(e.parameter.tunjangan) || 0;
    var cashbon = parseFloat(e.parameter.cashbon) || 0;
    
    var sheetPenggajian = ss.getSheetByName('Penggajian');
    if (!sheetPenggajian) {
      sheetPenggajian = ss.insertSheet('Penggajian');
      sheetPenggajian.appendRow(['Nama_Staff', 'BPJSTK', 'THR', 'Keterlambatan', 'Tunjangan', 'Cashbon']);
    }
    var data = sheetPenggajian.getDataRange().getValues();
    var found = false;
    for (var i = 1; i < data.length; i++) {
      if (data[i][0] == nama_staff) {
        sheetPenggajian.getRange(i+1, 2, 1, 5).setValues([[bpjstk, thr, keterlambatan, tunjangan, cashbon]]);
        found = true; break;
      }
    }
    if (!found) {
      sheetPenggajian.appendRow([nama_staff, bpjstk, thr, keterlambatan, tunjangan, cashbon]);
    }
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'message': 'Master gaji diupdate' })).setMimeType(ContentService.MimeType.JSON);
  }

  // ==========================================
  // 15. BAYAR GAJI
  // ==========================================
  else if (action == 'bayar_gaji') {
    var namaStaff = e.parameter.nama_staff;
    var totalBayar = parseFloat(e.parameter.total_bayar) || 0;
    var detailData = sheetDetail.getDataRange().getValues();
    var trxData = sheetTransaksi.getDataRange().getValues();
    
    var trxMap = {};
    for (var i = 1; i < trxData.length; i++) {
      trxMap[trxData[i][0].toString().trim()] = {
        'status': trxData[i][10] || 'Dikerjakan'
      };
    }

    // Hanya tandai 'Sudah Dibayar' untuk item sepatu yang SUDAH DIAMBIL pelanggan (Uang Real)
    // Sepatu yang masih Dikerjakan / Selesai (belum diambil) tetap berstatus 'Belum Dibayar' (Piutang)
    for (var i = 1; i < detailData.length; i++) {
      var curStaff = detailData[i][8] ? detailData[i][8].toString().trim() : '';
      var curStatus = detailData[i][9] ? detailData[i][9].toString().trim() : 'Belum Dibayar';
      if (curStaff == namaStaff && curStatus == 'Belum Dibayar') {
        var idTrx = detailData[i][1] ? detailData[i][1].toString().trim() : '';
        var trxInfo = trxMap[idTrx] || { 'status': 'Dikerjakan', 'nama_pelanggan': '-' };
        if (trxInfo.status === 'Diambil') {
          sheetDetail.getRange(i+1, 10).setValue('Sudah Dibayar');
          paidItems.push({
            'id_transaksi': idTrx,
            'nama_treatment': detailData[i][2] || '',
            'merek': detailData[i][5] || '',
            'jenis_item': detailData[i][4] || 'Sepatu',
            'pelanggan': trxInfo.nama_pelanggan || '-'
          });
        }
      }
    }
    
    var sheetLog = ss.getSheetByName('Log_Penggajian');
    if (sheetLog) {
      var tgl = new Date();
      var idLog = 'PAY-' + tgl.getTime();
      // Format tanggal pembayaran menggunakan WITA (Asia/Makassar UTC+8)
      var tglStr = Utilities.formatDate(tgl, "Asia/Makassar", 'yyyy-MM-dd HH:mm:ss');
      sheetLog.appendRow([idLog, tglStr, namaStaff, totalBayar, JSON.stringify(paidItems)]);
    }
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'message': 'Gaji ' + namaStaff + ' berhasil dibayarkan' })).setMimeType(ContentService.MimeType.JSON);
  }

  // ==========================================
  // 16. GET LOG PENGGAJIAN (Riwayat Pembayaran)
  // ==========================================
  else if (action == 'get_log_penggajian') {
    var sheetLog = ss.getSheetByName('Log_Penggajian');
    var logs = [];
    if (sheetLog) {
      var data = sheetLog.getDataRange().getValues();
      for (var i = data.length - 1; i >= 1; i--) {
        if (data[i][0]) {
          var items = [];
          if (data[i][4]) {
            try { items = JSON.parse(data[i][4]); } catch(err) {}
          }
          logs.push({
            'id_log': data[i][0] ? data[i][0].toString() : '',
            'tanggal': data[i][1] ? Utilities.formatDate(new Date(data[i][1]), "Asia/Makassar", 'yyyy-MM-dd HH:mm:ss') : '',
            'nama_staff': data[i][2] ? data[i][2].toString() : '',
            'total_bayar': parseFloat(data[i][3]) || 0,
            'items': items
          });
        }
      }
    }
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'data': logs })).setMimeType(ContentService.MimeType.JSON);
  }

  // ==========================================
  // 17. GET PENGATURAN ABSENSI
  // ==========================================
  else if (action == 'get_pengaturan_absensi') {
    var absSheets = getOrSetupAbsensiSheets(ss);
    var map = getPengaturanAbsensiMap(absSheets.pengaturan);
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'data': map })).setMimeType(ContentService.MimeType.JSON);
  }

  // ==========================================
  // 18. GET RIWAYAT ABSENSI
  // ==========================================
  else if (action == 'get_riwayat_absensi') {
    var absSheets = getOrSetupAbsensiSheets(ss);
    var data = absSheets.absensi.getDataRange().getValues();
    var list = [];
    var seenIds = {};
    for (var i = data.length - 1; i >= 1; i--) {
      var rowId = data[i][0] ? data[i][0].toString().trim() : '';
      if (rowId) {
        if (seenIds[rowId]) continue; // Abaikan baris duplikat
        seenIds[rowId] = true;

        list.push({
          'id_absen': rowId,
          'tanggal': data[i][1] ? data[i][1].toString() : '',
          'waktu_absen': data[i][2] ? data[i][2].toString() : '',
          'id_staff': data[i][3] ? data[i][3].toString() : '',
          'nama_staff': data[i][4] ? data[i][4].toString() : '',
          'tipe': data[i][5] ? data[i][5].toString() : 'Masuk',
          'status': data[i][6] ? data[i][6].toString() : 'Tepat Waktu',
          'menit_terlambat': parseFloat(data[i][7]) || 0,
          'potongan_gaji': parseFloat(data[i][8]) || 0,
          'lokasi': data[i][9] ? data[i][9].toString() : '',
          'link_foto': data[i][10] ? data[i][10].toString() : '',
          'waktu_sync': data[i][11] ? data[i][11].toString() : ''
        });
      }
    }
    return ContentService.createTextOutput(JSON.stringify({ 'status': 'success', 'data': list })).setMimeType(ContentService.MimeType.JSON);
  }

  // ACTION TIDAK DIKENALI
  return ContentService.createTextOutput(JSON.stringify({ 'status': 'error', 'message': 'Action tidak valid: ' + action })).setMimeType(ContentService.MimeType.JSON);
}

// ==========================================
// 17. DO POST UNTUK UPLOAD DOKUMEN PDF KE GOOGLE DRIVE
// ==========================================
function doPost(e) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var postData = {};
  try {
    postData = JSON.parse(e.postData.contents);
  } catch(err) {
    postData = e.parameter || {};
  }
  var action = postData.action || (e.parameter ? e.parameter.action : '');

  if (action == 'upload_slip_pdf') {
    try {
      var pdfBase64 = postData.pdf_base64;
      var fileName = postData.file_name || 'Slip_Gaji.pdf';
      var decoded = Utilities.base64Decode(pdfBase64);
      var blob = Utilities.newBlob(decoded, 'application/pdf', fileName);
      
      var folderName = 'Slip_Gaji_AhShoes';
      var folders = DriveApp.getFoldersByName(folderName);
      var folder = folders.hasNext() ? folders.next() : DriveApp.createFolder(folderName);
      
      var file = folder.createFile(blob);
      file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
      
      var downloadUrl = 'https://drive.google.com/uc?export=download&id=' + file.getId();
      var viewUrl = 'https://drive.google.com/file/d/' + file.getId() + '/view';
      
      return ContentService.createTextOutput(JSON.stringify({
        'status': 'success',
        'download_url': downloadUrl,
        'view_url': viewUrl
      })).setMimeType(ContentService.MimeType.JSON);
    } catch(err) {
      return ContentService.createTextOutput(JSON.stringify({
        'status': 'error',
        'message': err.toString()
      })).setMimeType(ContentService.MimeType.JSON);
    }
  }

  // ==========================================
  // ABSENSI: PROSES CATAT ABSEN + FOTO DRIVE
  // ==========================================
  else if (action == 'absen') {
    try {
      var absSheets = getOrSetupAbsensiSheets(ss);
      var config = getPengaturanAbsensiMap(absSheets.pengaturan);

      var id_staff = postData.id_staff || '';
      var nama_staff = postData.nama_staff || '';
      var tipe = postData.tipe || 'Masuk'; // Masuk / Pulang
      var waktu_absen = postData.waktu_absen || ''; // Waktu lokal perangkat saat klik absen
      var lokasi = postData.lokasi || '';
      var foto_base64 = postData.foto_base64 || '';

      var now = new Date();
      var waktu_sync = Utilities.formatDate(now, "Asia/Makassar", 'yyyy-MM-dd HH:mm:ss');
      if (!waktu_absen) waktu_absen = waktu_sync;

      var tanggal = waktu_absen.split(' ')[0] || Utilities.formatDate(now, "Asia/Makassar", 'yyyy-MM-dd');
      var jamMenitStr = waktu_absen.split(' ')[1] || Utilities.formatDate(now, "Asia/Makassar", 'HH:mm:ss');

      var menit_terlambat = 0;
      var potongan = 0;
      var statusKehadiran = 'Tepat Waktu';

      if (tipe === 'Masuk') {
        var targetMenit = parseMinutesFromTime(config.jam_masuk, 8, 0);
        var toleransi = parseInt(config.toleransi_menit || '15', 10);
        var dendaPerMenit = parseFloat(config.denda_per_menit || '1000');

        var actualMenit = parseMinutesFromTime(jamMenitStr, now.getHours(), now.getMinutes());

        if (actualMenit > (targetMenit + toleransi)) {
          menit_terlambat = actualMenit - (targetMenit + toleransi);
          potongan = menit_terlambat * dendaPerMenit;
          statusKehadiran = 'Terlambat ' + menit_terlambat + ' Mnt';

          // Otomatis akumulasikan pemotongan ke Sheet Penggajian (Master Gaji)
          var sheetPenggajian = ss.getSheetByName('Penggajian');
          if (sheetPenggajian) {
            var pgData = sheetPenggajian.getDataRange().getValues();
            for (var p = 1; p < pgData.length; p++) {
              if (pgData[p][0] && pgData[p][0].toString().trim().toLowerCase() === nama_staff.toLowerCase()) {
                var curTerlambat = parseFloat(pgData[p][3]) || 0;
                sheetPenggajian.getRange(p+1, 4).setValue(curTerlambat + potongan);
                break;
              }
            }
          }
        } else {
          statusKehadiran = 'Tepat Waktu';
        }
      } else {
        // Tipe Pulang
        statusKehadiran = 'Selesai Kerja';
      }

      // Simpan foto selfie ke Google Drive jika ada
      var linkFotoDrive = '';
      if (foto_base64) {
        try {
          var folder = getOrCreateAbsensiFolder(config.folder_drive_id);
          var fileName = 'Selfie_' + nama_staff.replace(/\s+/g, '_') + '_' + now.getTime() + '.jpg';
          linkFotoDrive = saveAbsensiPhotoToDrive(folder, foto_base64, fileName);
        } catch(photoErr) {
          linkFotoDrive = 'Gagal upload drive: ' + photoErr.toString();
        }
      }

      var idAbsen = postData.id_absen || ('ABS-' + now.getTime());

      // Cegah duplikasi data jika request terkirim lebih dari satu kali
      var absData = absSheets.absensi.getDataRange().getValues();
      for (var r = 1; r < absData.length; r++) {
        var existingId = absData[r][0] ? absData[r][0].toString().trim() : '';
        if (existingId && existingId === idAbsen.toString().trim()) {
          return ContentService.createTextOutput(JSON.stringify({
            'status': 'success',
            'message': 'Absensi ' + idAbsen + ' sudah pernah tercatat (duplikat diabaikan)',
            'id_absen': idAbsen,
            'status_kehadiran': absData[r][6] || statusKehadiran,
            'menit_terlambat': parseFloat(absData[r][7]) || menit_terlambat,
            'potongan': parseFloat(absData[r][8]) || potongan,
            'link_foto': absData[r][10] || linkFotoDrive,
            'waktu_absen': absData[r][2] || waktu_absen
          })).setMimeType(ContentService.MimeType.JSON);
        }
      }

      absSheets.absensi.appendRow([
        idAbsen,
        tanggal,
        waktu_absen,
        id_staff,
        nama_staff,
        tipe,
        statusKehadiran,
        menit_terlambat,
        potongan,
        lokasi,
        linkFotoDrive,
        waktu_sync
      ]);

      return ContentService.createTextOutput(JSON.stringify({
        'status': 'success',
        'message': 'Absensi ' + tipe + ' ' + nama_staff + ' berhasil dicatat!',
        'id_absen': idAbsen,
        'status_kehadiran': statusKehadiran,
        'menit_terlambat': menit_terlambat,
        'potongan': potongan,
        'link_foto': linkFotoDrive,
        'waktu_absen': waktu_absen
      })).setMimeType(ContentService.MimeType.JSON);
    } catch(err) {
      return ContentService.createTextOutput(JSON.stringify({
        'status': 'error',
        'message': 'Gagal memproses absensi: ' + err.toString()
      })).setMimeType(ContentService.MimeType.JSON);
    }
  }

  // ==========================================
  // UPDATE PENGATURAN ABSENSI
  // ==========================================
  else if (action == 'update_pengaturan_absensi') {
    try {
      var absSheets = getOrSetupAbsensiSheets(ss);
      var keys = ['jam_masuk', 'jam_pulang', 'toleransi_menit', 'denda_per_menit', 'lokasi_lat', 'lokasi_lng', 'radius_meter', 'folder_drive_id'];
      var data = absSheets.pengaturan.getDataRange().getValues();
      var rowMap = {};
      for (var r = 1; r < data.length; r++) {
        if (data[r][0]) rowMap[data[r][0].toString().trim()] = r + 1;
      }

      for (var k = 0; k < keys.length; k++) {
        var key = keys[k];
        if (postData[key] !== undefined) {
          var val = postData[key];
          if (rowMap[key]) {
            absSheets.pengaturan.getRange(rowMap[key], 2).setValue(val);
          } else {
            absSheets.pengaturan.appendRow([key, val]);
          }
        }
      }

      return ContentService.createTextOutput(JSON.stringify({
        'status': 'success',
        'message': 'Pengaturan absensi berhasil diperbarui'
      })).setMimeType(ContentService.MimeType.JSON);
    } catch(err) {
      return ContentService.createTextOutput(JSON.stringify({
        'status': 'error',
        'message': err.toString()
      })).setMimeType(ContentService.MimeType.JSON);
    }
  }

  return ContentService.createTextOutput(JSON.stringify({
    'status': 'error',
    'message': 'Post action tidak valid: ' + action
  })).setMimeType(ContentService.MimeType.JSON);
}

// ==========================================
// HELPER ABSENSI & GOOGLE DRIVE
// ==========================================
function getOrSetupAbsensiSheets(ss) {
  var sheetAbsensi = ss.getSheetByName('Absensi');
  if (!sheetAbsensi) {
    sheetAbsensi = ss.insertSheet('Absensi');
    sheetAbsensi.appendRow([
      'id_absen', 'tanggal', 'waktu_absen', 'id_staff', 'nama_staff', 
      'tipe', 'status', 'menit_terlambat', 'potongan_gaji', 
      'lokasi_lat_long', 'link_foto_drive', 'waktu_sinkron'
    ]);
  }

  var sheetPengaturan = ss.getSheetByName('Pengaturan_Absensi');
  if (!sheetPengaturan) {
    sheetPengaturan = ss.insertSheet('Pengaturan_Absensi');
    sheetPengaturan.appendRow(['kunci', 'nilai']);
    sheetPengaturan.appendRow(['jam_masuk', '08:00']);
    sheetPengaturan.appendRow(['jam_pulang', '17:00']);
    sheetPengaturan.appendRow(['toleransi_menit', '15']);
    sheetPengaturan.appendRow(['denda_per_menit', '1000']);
    sheetPengaturan.appendRow(['lokasi_lat', '-8.650000']);
    sheetPengaturan.appendRow(['lokasi_lng', '115.216667']);
    sheetPengaturan.appendRow(['radius_meter', '100']);
    sheetPengaturan.appendRow(['folder_drive_id', '']);
  }

  return { absensi: sheetAbsensi, pengaturan: sheetPengaturan };
}

function parseMinutesFromTime(val, defaultH, defaultM) {
  if (defaultH === undefined) defaultH = 8;
  if (defaultM === undefined) defaultM = 0;
  if (!val) return (defaultH * 60) + defaultM;

  if (Object.prototype.toString.call(val) === '[object Date]' || (val && typeof val.getTime === 'function')) {
    try {
      var h = val.getHours();
      var m = val.getMinutes();
      return (h * 60) + m;
    } catch(e) {}
  }

  var s = String(val).trim();
  if (s.indexOf('T') !== -1) {
    try {
      var d = new Date(s);
      if (!isNaN(d.getTime())) {
        var str = Utilities.formatDate(d, "Asia/Makassar", "HH:mm");
        var p = str.split(':');
        return (parseInt(p[0], 10) * 60) + parseInt(p[1], 10);
      }
    } catch(e) {}
  }

  var match = s.match(/(\d{1,2}):(\d{1,2})/);
  if (match) {
    return (parseInt(match[1], 10) * 60) + parseInt(match[2], 10);
  }
  return (defaultH * 60) + defaultM;
}

function formatTimeOnly(val) {
  if (!val) return '08:00';
  if (Object.prototype.toString.call(val) === '[object Date]' || (val && typeof val.getTime === 'function')) {
    try {
      return Utilities.formatDate(val, "Asia/Makassar", "HH:mm");
    } catch(e) {}
  }
  var s = String(val).trim();
  if (s.indexOf('T') !== -1) {
    try {
      var d = new Date(s);
      if (!isNaN(d.getTime())) {
        return Utilities.formatDate(d, "Asia/Makassar", "HH:mm");
      }
    } catch(e) {}
  }
  var match = s.match(/(\d{1,2}):(\d{1,2})/);
  if (match) {
    var h = ('0' + match[1]).slice(-2);
    var m = ('0' + match[2]).slice(-2);
    return h + ':' + m;
  }
  return s || '08:00';
}

function getPengaturanAbsensiMap(sheetPengaturan) {
  var data = sheetPengaturan.getDataRange().getValues();
  var map = {
    'jam_masuk': '08:00',
    'jam_pulang': '17:00',
    'toleransi_menit': 15,
    'denda_per_menit': 1000,
    'lokasi_lat': -8.65,
    'lokasi_lng': 115.22,
    'radius_meter': 100,
    'folder_drive_id': ''
  };
  for (var i = 1; i < data.length; i++) {
    var key = data[i][0] ? String(data[i][0]).trim().toLowerCase() : '';
    var val = data[i][1];
    if (key.indexOf('masuk') !== -1) {
      map['jam_masuk'] = formatTimeOnly(val);
    } else if (key.indexOf('pulang') !== -1) {
      map['jam_pulang'] = formatTimeOnly(val);
    } else if (key.indexOf('toleransi') !== -1) {
      map['toleransi_menit'] = parseInt(val, 10) || 15;
    } else if (key.indexOf('denda') !== -1) {
      map['denda_per_menit'] = parseFloat(val) || 1000;
    } else if (key.indexOf('lat') !== -1) {
      var parsedLat = parseFloat(val) || -8.65;
      while (Math.abs(parsedLat) > 90) { parsedLat /= 10.0; }
      map['lokasi_lat'] = parsedLat;
    } else if (key.indexOf('lng') !== -1) {
      var parsedLng = parseFloat(val) || 115.22;
      while (Math.abs(parsedLng) > 180) { parsedLng /= 10.0; }
      map['lokasi_lng'] = parsedLng;
    } else if (key.indexOf('radius') !== -1) {
      map['radius_meter'] = parseFloat(val) || 100;
    } else if (key.indexOf('folder') !== -1) {
      map['folder_drive_id'] = String(val || '').trim();
    } else if (key) {
      map[key] = String(val);
    }
  }
  return map;
}

function getOrCreateAbsensiFolder(folderId) {
  if (folderId) {
    try { return DriveApp.getFolderById(folderId); } catch(e) {}
  }
  var folders = DriveApp.getFoldersByName('Foto_Absensi_AhShoes');
  if (folders.hasNext()) return folders.next();
  return DriveApp.createFolder('Foto_Absensi_AhShoes');
}

function saveAbsensiPhotoToDrive(folder, base64Data, fileName) {
  var cleanBase64 = base64Data.replace(/^data:image\/\w+;base64,/, '');
  var bytes = Utilities.base64Decode(cleanBase64);
  var blob = Utilities.newBlob(bytes, 'image/jpeg', fileName);
  var file = folder.createFile(blob);
  file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
  return 'https://drive.google.com/uc?export=view&id=' + file.getId();
}
function parseTextBahanBaku(bahanBakuStr) {
  var results = [];
  if (!bahanBakuStr) return results;
  var lines = bahanBakuStr.toString().split('\n');
  var regex = /^\d+\.\s*(.+?)\s+(\d+(?:\.\d+)?)\s*$/;
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim();
    if (!line) continue;
    var match = line.match(regex);
    if (match) {
      results.push({
        nama: match[1].trim().toLowerCase(),
        qty: parseFloat(match[2])
      });
    }
  }
  return results;
}
