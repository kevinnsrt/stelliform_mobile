import 'package:flutter/foundation.dart';
import 'package:stelliform_mobile/core/network/api_client.dart';
import 'package:stelliform_mobile/features/finance/data/finance_models.dart';
import 'package:stelliform_mobile/features/finance/data/finance_repository.dart';

/// Controller managing operational expenses, payroll disbursement, and P&L reporting.
class FinanceController extends ChangeNotifier {
  /// Creates a [FinanceController] backed by [repository].
  FinanceController({required FinanceRepository repository})
    : _repository = repository;

  final FinanceRepository _repository;

  String _selectedPeriod = 'Bulan Ini';
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  ApiException? _lastException;

  /// Active reporting period label (`Hari Ini`, `Minggu Ini`, `Bulan Ini`).
  String get selectedPeriod => _selectedPeriod;

  /// Available P&L reporting periods.
  List<String> get availablePeriods => const [
    'Hari Ini',
    'Minggu Ini',
    'Bulan Ini',
  ];

  /// All recorded operational expenses.
  List<ExpenseEntry> get expenses => _repository.getExpenses();

  /// Total operational expenses across recorded entries.
  double get totalRecordedExpenses =>
      expenses.fold(0, (sum, entry) => sum + entry.amount);

  /// Employee payroll records for the current billing cycle.
  List<PayrollEntry> get payrollEntries => _repository.getPayrollEntries();

  /// Total payroll amount due or paid.
  double get totalPayroll =>
      payrollEntries.fold(0, (sum, entry) => sum + entry.netSalary);

  /// Count of employees whose salary has been marked paid.
  int get paidPayrollCount => payrollEntries.where((e) => e.isPaid).length;

  /// Live Profit & Loss calculation for [_selectedPeriod].
  PnlSummary get pnlSummary =>
      _repository.computePnlSummary(periodLabel: _selectedPeriod);

  /// Whether remote finance data is currently loading.
  bool get isLoading => _isLoading;

  /// Whether a financial write action is currently running.
  bool get isSubmitting => _isSubmitting;

  /// Latest validation or submission error message.
  String? get errorMessage => _errorMessage;

  /// Latest structured [ApiException] from Finance endpoints.
  ApiException? get lastException => _lastException;

  /// Fetches live Finance metrics and expenses from the backend API.
  Future<void> loadFinanceData() async {
    if (!_repository.enableRemoteSync) return;
    _isLoading = true;
    _errorMessage = null;
    _lastException = null;
    notifyListeners();

    try {
      await _repository.fetchRemotePnlSummary(periodLabel: _selectedPeriod);
      await _repository.fetchExpenses();
    } on ApiException catch (error) {
      _lastException = error;
      _errorMessage = error.detailedMessage;
    } catch (_) {
      _errorMessage = 'Gagal memuat laporan keuangan dari server.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Switches the active reporting period and refreshes P&L metrics.
  void setSelectedPeriod(String period) {
    _selectedPeriod = period;
    notifyListeners();
    if (_repository.enableRemoteSync) {
      loadFinanceData();
    }
  }

  /// Submits a new operational expense entry.
  Future<bool> submitExpense({
    required String title,
    required ExpenseCategory category,
    required double amount,
    required String recordedBy,
    String notes = '',
  }) async {
    if (title.trim().isEmpty) {
      _errorMessage = 'Judul pengeluaran wajib diisi.';
      notifyListeners();
      return false;
    }
    if (amount <= 0) {
      _errorMessage = 'Nominal pengeluaran harus lebih dari Rp 0.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    _lastException = null;
    notifyListeners();

    try {
      await _repository.addExpense(
        title: title,
        category: category,
        amount: amount,
        recordedBy: recordedBy,
        notes: notes,
      );
      return true;
    } on ApiException catch (error) {
      _lastException = error;
      _errorMessage = error.detailedMessage;
      return false;
    } catch (_) {
      _errorMessage = 'Gagal menyimpan pengeluaran operasional.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Toggles disbursement state of a staff payroll entry.
  Future<void> togglePayrollPaid(String payrollId) async {
    await _repository.togglePayrollPaid(payrollId);
    notifyListeners();
  }
}
